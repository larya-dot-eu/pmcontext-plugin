---
description: Pre-deploy gates against a running system — prove the artifact, replay the access-control matrix as real requests, check operational readiness, then deploy with a verified rollback target
---

## Config

Read the config file via Bash tool:
```bash
cat ~/.pmcontext 2>/dev/null
```

Extract:
- Value after `SUPABASE_PROJECT_ID=` → `<PROJECT_ID>`
- Value after `PLUGIN_DIR=` → `<PLUGIN_DIR>`

If the file is missing or `SUPABASE_PROJECT_ID` is blank, output and stop:
```
[BLOCKED] pmcontext is not configured.
Run /pmcontext:init to complete setup.
```

Detect the current project name:
- Run `git rev-parse --show-toplevel 2>/dev/null | xargs basename | tr -cd 'a-zA-Z0-9_-'` via Bash tool.
- If not in a git repo, run `basename "$PWD" | tr -cd 'a-zA-Z0-9_-'` instead.
- Use this value as `<project>` in all SQL WHERE clauses below.

> **Supabase MCP tool names:** `mcp__claude_ai_Supabase__*` below assumes the common Supabase MCP install. If your server uses a different prefix, call the equivalent tool from whatever Supabase MCP is available — same SQL, same parameters.

**Argument:** `$ARGUMENTS` may contain `--gate-only`. If present, run every gate and the report, then stop before the deploy confirmation — nothing outside this machine is touched.

---

## The rule this command exists for

Every other phase reads documents. This one runs the system. The spec's access-control matrix is an *assertion*; here it becomes a request that either gets a 403 or does not. **Where this command and the matrix disagree, this command is right and the matrix is wrong** — fix the matrix, do not explain away the result.

A gate is PASS only when a command was run and its output observed. Never infer PASS from reading code. If a check cannot be run, it is `N/A` with a reason — never a silent PASS.

---

## Step 1 — Detect the deploy target

Look for what this project actually does to ship. Run via Bash tool:
```bash
ls Dockerfile Procfile fly.toml vercel.json netlify.toml render.yaml 2>/dev/null
grep -sE '"(deploy|build|start)"' package.json 2>/dev/null
ls .github/workflows/ 2>/dev/null
grep -sE '^(deploy|build|release):' Makefile 2>/dev/null
```

Also read `CLAUDE.md` for a documented deploy command.

Then classify, and say which one you picked and why:

| What you found | Classification |
|---|---|
| A deploy target and a long-running HTTP service | **Service** — every gate below applies |
| A build/publish step but no HTTP surface (library, CLI, plugin, static site) | **Artifact** — Gate A applies, Gate B/C are mostly `N/A`, say so per check |
| Nothing | **Unknown** — ask the user for the deploy command and how the thing is served. Do not guess. |

If the project is **Artifact**-classified, do not invent an HTTP surface to test. Mark the request-based checks `N/A — no HTTP surface` and run what remains (build, boot/import, secrets, dependency integrity).

---

## Step 2 — Load what the gates are scored against

Read the project's `CLAUDE.md` and extract:
- The `### Access Control` table → this is Gate B's checklist. Every `(Role, Resource)` row is a test case.
- The `### Expected Scale` table → this is Gate C's numbers.

If `CLAUDE.md` has no `### Access Control` section, output and continue:
```
[WARN] No access-control matrix in CLAUDE.md — Gate B has nothing to replay.
Gate B will fall back to discovering routes and reporting what it finds, which is
weaker: it can catch an open route, but it cannot know a boundary is missing.
Run /pmcontext:plan on this project to build the matrix.
```

Query the open session, if any:
```sql
SELECT id, plan_name, tier
FROM pm_sessions
WHERE project = '<project>'
  AND status IN ('active', 'paused')
ORDER BY updated_at DESC
LIMIT 1;
```
Note `id` as `<SESSION_ID>` if found — gate results attach to it. Deploying with no open session is fine (deploying work closed in an earlier session).

---

## Gate A — Deployable artifact

Prove the thing builds and boots **here**, from a clean tree, before production is involved.

| Check | How | FAIL when |
|---|---|---|
| Clean build | Build from a clean state (no cached artifacts, no `node_modules` shortcuts — the CI path, not the dev path) | Build fails, or only works with local state that is not committed |
| Boots | Start the built artifact. Service → it listens. Artifact → it imports/runs `--help` without error | It does not start, or errors on load |
| Health responds | `curl -fsS <health-url>` — the app's own health endpoint if it has one, otherwise any route that proves it serves. **Service only.** | Non-2xx, or no health surface exists at all (that itself is a finding — say so) |
| Committed | `git status --porcelain` is empty and HEAD is pushed | You are about to deploy code that exists only on this machine |
| Secrets | The built artifact contains no credentials — see the grep below | A literal secret is in the artifact |

Secret scan (run against the build output, not the source tree):
```bash
grep -rIEn "(api[_-]?key|secret|password|token)[[:space:]]*[=:][[:space:]]*[\"'][^\"']{8,}" <build-output>
```
Exit 1 (no match) is the PASS. Any hit is a FAIL until proven to be a placeholder.

**Do not proceed past Gate A on a FAIL.** Every later gate tests the artifact this one produced.

---

## Gate B — Security, against real requests

For each `(Role, Resource)` row in the access-control matrix, issue actual requests to the locally running artifact and observe the status codes. This is the gate that makes P2's matrix real.

| Check | How | PASS |
|---|---|---|
| **Auth required** | Request each non-`anon` resource with no credentials | 401/403 — never 200 |
| **IDOR replay** | Authenticate as user A, create a row, capture its id. Authenticate as user B, request A's id — read, then update, then delete | All three denied for every row the matrix scopes with an ownership key |
| **Role separation** | Request an `admin`-only resource as a plain `user` | Denied |
| **Ownership on write** | Create a row while passing a *different* owner id in the body than the session's | Server ignores the body and uses the session identity |
| **Input validation** | Send each new input wrong: absent, wrong type, oversized, and with a quote/`<script>` payload | Rejected server-side with a 4xx — not a 500, not stored |
| **Parameterized queries** | Grep for string-built SQL — see below | No query built by string concatenation |
| **Cookies** | Inspect `Set-Cookie` on login | `HttpOnly`, `Secure`, `SameSite` all present on session cookies |
| **CORS** | Read the CORS config; send a cross-origin preflight | Not `*` on any credentialed route |
| **Rate limiting** | Hammer the login/expensive route ~50× | Something throttles — a 429 appears |
| **Error hygiene** | Trigger a 500 deliberately | No stack trace, SQL, or internal path in the response body |

String-built SQL scan (adjust the source dir to the project):
```bash
grep -rnE "(query|execute)\([^)]*\+" <src>
grep -rnE "(SELECT|INSERT|UPDATE|DELETE)[^;]*\\\$\{" <src>
```
Exit 1 on both is the PASS. A hit means a query is assembled from a string — read it and confirm whether user input can reach it.

**Every check reports the actual status code observed, not "verified".** `user B → GET /api/<resource>/<A's id> → 403` is evidence; "IDOR protected" is not.

**Matrix disagreements are findings about the matrix.** If the matrix says `own only` and user B gets a 200, that is a live vulnerability — stop, report `[RISK]`, do not deploy. If the matrix says `own only` and the resource does not exist at all, the matrix is stale — fix it.

---

## Gate C — Operational readiness

Scored against the `### Expected Scale` numbers.

| Check | How | FAIL when |
|---|---|---|
| Hot queries indexed | `EXPLAIN` each query the scale table lists as hot | A sequential scan on a table the table says will grow |
| Survives restart | Kill the process, start it again, exercise the feature | State was in process memory and is now gone |
| Second replica | Start a second instance against the same data store; exercise both | They disagree — the feature assumed it was alone |
| Unbounded growth | For each table the scale table marks unbounded, confirm the retention/pagination/archival that bounds it exists | Nothing bounds it and nothing is planned |
| Monitoring | Name where errors surface and what alerts a human | Nobody would find out this broke except a user |
| Backpressure | What happens when a dependency is slow or down — timeout, retry, circuit break | It hangs forever or retries without limit |

For **Artifact**-classified projects most rows here are `N/A — no runtime`; say which and move on.

---

## Step 3 — Verify the rollback target

Before anything irreversible, establish what you would roll *back to*, and prove it exists:
```bash
git tag --sort=-creatordate | head -5
git log --oneline -5
```

State plainly: **the exact version/tag/commit currently in production**, how it is redeployed, and how long that takes. If nobody can name the currently-deployed version, there is no rollback target — that is a FAIL, and it blocks the deploy regardless of every other gate.

---

## Step 4 — Report to the PM

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  DEPLOY GATES — <project>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Target:   <service | artifact> — <deploy command>

  GATE A — ARTIFACT          <PASS | FAIL>
  <one line per check, with what was observed>

  GATE B — SECURITY          <PASS | FAIL>
  <one line per (Role, Resource) row, with the status codes seen>

  GATE C — OPERATIONAL       <PASS | FAIL>
  <one line per check, with the number or output observed>

  ROLLBACK TO               <version/tag> — <how, how long>

  N/A CHECKS
  <every skipped check and why — never hidden>

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  VERDICT: <SAFE TO DEPLOY | DO NOT DEPLOY>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Write the gate results to the session's `phase_gates` (JSONB — no schema change needed). Double every single quote in free text (`'` → `''`) before substituting.

**If `<SESSION_ID>` exists:**
```sql
UPDATE pm_sessions
SET phase_gates = phase_gates || jsonb_build_object(
    'deploy', jsonb_build_object(
        'gate_a_artifact', '<PASS/FAIL + what was observed>',
        'gate_b_security', '<PASS/FAIL + status codes per matrix row>',
        'gate_c_operational', '<PASS/FAIL + numbers observed>',
        'na_checks', '<every skipped check and why>',
        'rollback_target', '<version + how>',
        'verdict', '<SAFE TO DEPLOY | DO NOT DEPLOY>',
        'gated_at', NOW()
    )
),
updated_at = NOW()
WHERE id = '<SESSION_ID>';
```

**If no open session,** insert one to carry the record. Leave `session_type` at its default — the schema's CHECK constraint allows only `planning`/`execution`, and adding a `deploy` type would require an ALTER that `CREATE TABLE IF NOT EXISTS` never applies to already-configured installs:
```sql
INSERT INTO pm_sessions (project, status, plan_name, phase_gates, started_at, updated_at)
VALUES ('<project>', 'active', 'deploy: <what is shipping>', '<deploy_gates_json>', NOW(), NOW());
```

**On `DO NOT DEPLOY`, or if `--gate-only` was passed: stop here.**

---

## Step 5 — Deploy

Only reachable when every gate passed and a rollback target is named.

**Stop and ask. Do not deploy without an explicit yes in this session:**
```
[RISK] Ready to deploy <project> to production.

  Shipping:     <what changed, in PM language>
  Rolling back to <version> takes <duration> via <command>
  Access changes going live: <any widened (Role, Resource) row — or "none">

  Deploy now? (yes / no)
```

Anything other than a clear yes: stop, and say the gates remain green so it can be picked up later.

On yes, in this order — **irreversible last**:

1. **Deploy** — run the deploy command. Capture its output.
2. **Confirm health** — poll the real production health endpoint until it responds 2xx, or fail after a bounded wait. Never assume the deploy worked because the command exited 0.
3. **Re-run the smallest Gate B check against production** — one unauthenticated request to a non-`anon` resource. It must be denied. This catches the config that was right locally and wrong in prod, which is the failure this whole command exists to prevent.
4. **Watch** — check errors/logs for a few minutes before declaring done. A deploy that 500s on the third request is not a successful deploy.
5. **Only now** — merge the branch, tag the release, announce. These are the irreversible, outward-facing steps and they go after production is confirmed healthy, never before.

If any step fails: **roll back first, diagnose second.** Execute the rollback to the named target, confirm health returns, then report what happened. Do not debug a broken production.

Record the outcome:
```sql
UPDATE pm_sessions
SET phase_gates = phase_gates || jsonb_build_object(
    'deploy_result', jsonb_build_object(
        'deployed', <true/false>,
        'version', '<what shipped>',
        'health_confirmed', <true/false>,
        'prod_auth_recheck', '<status code observed>',
        'rolled_back', '<false, or why>',
        'deployed_at', NOW()
    )
),
updated_at = NOW()
WHERE id = '<SESSION_ID>';
```

Then tell the PM what is live, what to watch, and how to roll back — in plain language, no commands they did not ask for.

Run `/pmcontext:close` to write the session receipt.
