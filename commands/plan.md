---
description: Run the PM-Claude planning workflow — context priming, exploration, spec writing, plan writing, and adversarial review — produces a plan file ready for /pmcontext:execute
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

Detect tier from $ARGUMENTS:
- If $ARGUMENTS contains `--full` → `<TIER>` = `full`
- Otherwise → `<TIER>` = `standard`

Output at the start of the session:
```
[TIER] Running /pmcontext:plan in <TIER> tier.
  standard — all phases, markdown outputs, abbreviated adversarial review
  full     — all phases, HTML companions, full adversarial review with loop-back analysis
```

Detect the current project name:
- Run `git rev-parse --show-toplevel 2>/dev/null | xargs basename | tr -cd 'a-zA-Z0-9_-'` via Bash tool.
- If not in a git repo, run `basename "$PWD" | tr -cd 'a-zA-Z0-9_-'` instead.
- Use this value as `<project>` in SQL WHERE clauses below.

> **Supabase MCP tool names:** `mcp__claude_ai_Supabase__*` below assumes the common Supabase MCP install. If your server uses a different prefix, call the equivalent tool from whatever Supabase MCP is available — same SQL, same parameters.

## Prerequisite Check

**Required — abort if missing:**
- Supabase MCP: if unavailable, output and stop:
  ```
  [BLOCKED] /pmcontext:plan requires Supabase MCP
  ```

**Recommended — warn and continue if missing:**
- `superpowers:brainstorming`:
  `[WARN] superpowers:brainstorming not found — exploratory workflow will be fully manual`
- context7 MCP:
  `[WARN] context7 MCP not found — library documentation lookups unavailable during planning`

## Ensure Output Directories

Run via Bash tool:
```bash
mkdir -p docs/superpowers/specs docs/superpowers/plans
```

If a `.gitignore` exists in the project root, check whether `docs/superpowers/` is already ignored:
```bash
grep -q "docs/superpowers" .gitignore 2>/dev/null && echo "ignored" || echo "not ignored"
```

If not ignored, append it:
```bash
echo "docs/superpowers/" >> .gitignore
```

## Load Mandatory Context Set

**Static tier (full — files + Supabase):**

Run file checks in parallel via Bash tool:
```bash
test -f CLAUDE.md && echo "exists" || echo "missing"
test -f ROADMAP.md && echo "exists" || echo "missing"
test -f CONTEXT.md && echo "exists" || echo "missing"
test -f PROJECT_BRIEF.md && echo "exists" || echo "missing"
```

Read each file that exists. Missing files: warn and continue — do not block.

- **`CLAUDE.md`** — architecture rules, stack conventions, coding patterns, constraints
- **`ROADMAP.md`** — current priorities and already-decided directions
- **`CONTEXT.md`** — Node Model (Surface vs Core nodes)
- **`PROJECT_BRIEF.md`** — Surface Node Inventory and Core Node Map

Query open decisions and active risks via `mcp__claude_ai_Supabase__execute_sql` with `project_id = <PROJECT_ID>`:
```sql
SELECT open_decisions, active_risks
FROM pm_state
WHERE project = '<project>';
```

Output:
```
[CONTEXT LOADED]
  CLAUDE.md          ✓     (or [missing])
  ROADMAP.md         ✓     (or [missing])
  CONTEXT.md         ✓     (or [missing])
  PROJECT_BRIEF.md   ✓     (or [missing])
  pm_state           ✓ (<n> open decisions, <n> active risks)    (or [no row])
```

After loading, summarize to the user:
- What you understand about the current project state
- Which architectural patterns and constraints apply to this session
- Any open decisions or active risks relevant to this work

Do not proceed to Phase 1 until the user confirms the summary is correct or provides corrections.

## Create Phase Tasks

Create all phase tasks now so the full workflow is visible throughout the session. Use TaskCreate for each:

1. `Prerequisites — Load project context` — mark as completed immediately
2. `Phase 1 — Context Priming`
3. `Phase 2 — Exploration (PM Mode: questions only, no solutions)`
4. `Phase 3 — Spec Writing`
5. `Phase 4 — Plan Writing`
6. `Phase 5 — Adversarial Review`
7. `Living Doc Update — update CLAUDE.md and ROADMAP.md if needed`

Note each task ID. Mark the Prerequisites task as completed now.

## Create Planning Session Row

Run via `mcp__claude_ai_Supabase__execute_sql` with `project_id = <PROJECT_ID>`:

```sql
INSERT INTO pm_sessions (project, session_type, tier, status, started_at, updated_at)
VALUES ('<project>', 'planning', '<TIER>', 'active', NOW(), NOW())
RETURNING id;
```

Note the returned `id` as `<PLANNING_SESSION_ID>`.

---

## Phase 1 — Context Priming

Mark the Phase 1 task as in_progress.

Confirm your working model of the project before any exploration begins.

State explicitly:
- The current relevant architecture and patterns
- Known constraints from `CLAUDE.md` and `ROADMAP.md`
- Stack conventions (integration patterns, external services, APIs, databases)
- Any prior decisions relevant to this session

**Exit gate:** *"Is this an accurate picture of the project context? Anything to correct or add before we explore the problem?"*
Do not proceed to Phase 2 until the user confirms. Then write the Phase 1 gate and mark the task as completed:

```sql
UPDATE pm_sessions
SET phase_gates = phase_gates || jsonb_build_object(
    'phase_1', jsonb_build_object('approved_at', NOW())
),
updated_at = NOW()
WHERE id = '<PLANNING_SESSION_ID>';
```

---

## Phase 2 — Exploration (PM Mode)

Mark the Phase 2 task as in_progress.

Verify the Phase 1 gate was recorded before proceeding. Run via `mcp__claude_ai_Supabase__execute_sql` with `project_id = <PROJECT_ID>`:

```sql
SELECT (phase_gates->>'phase_1') IS NOT NULL AS gate_cleared
FROM pm_sessions WHERE id = '<PLANNING_SESSION_ID>';
```

If `gate_cleared = false`, output and stop:
```
[BLOCKED] Phase 1 gate not recorded. Complete Phase 1 and confirm with the user before proceeding.
```

Your role in this phase is to ask clarifying questions only. Do not propose solutions. Do not write specs. Do not suggest implementations.

Ask the user to define:
- **The why:** What problem does this solve? Why now?
- **The constraints:** Technical, time-based, dependency-based
- **What makes this case different:** How does this deviate from existing patterns in the codebase?

While exploring, surface:
- Ambiguities and unstated assumptions
- Which parts of the existing codebase are affected
- Anything in the existing code that complicates the request

**Exit gate (hard stop):** Before proceeding to Phase 3, you must be able to answer all three:
1. What is the exact problem being solved?
2. What are the constraints?
3. What makes this case different from existing patterns?

If you cannot answer all three clearly — stay in Phase 2. When all three are answered and the user confirms, write the Phase 2 gate and mark the task as completed:

```sql
UPDATE pm_sessions
SET phase_gates = phase_gates || jsonb_build_object(
    'phase_2', jsonb_build_object(
        'why_answered', true,
        'constraints_answered', true,
        'difference_answered', true,
        'approved_at', NOW()
    )
),
updated_at = NOW()
WHERE id = '<PLANNING_SESSION_ID>';
```

---

## Phase 3 — Spec Writing

Mark the Phase 3 task as in_progress.

Verify the Phase 2 gate was recorded:

```sql
SELECT (phase_gates->>'phase_2') IS NOT NULL AS gate_cleared
FROM pm_sessions WHERE id = '<PLANNING_SESSION_ID>';
```

If `gate_cleared = false`, output and stop:
```
[BLOCKED] Phase 2 gate not recorded. The exploration exit gate (why, constraints, difference) must be confirmed before writing a spec.
```

**Step 1 — Identify affected files:**

From the Phase 2 exploration output, list the files most likely to be touched by this feature. Read each one now using the Read tool. If no files can be identified from Phase 2, ask the user to name at least one file before proceeding. This is a preliminary list — Phase 4 codebase sync will finalize and may extend it.

**Step 2 — Copy spec skeleton:**

Read `$PLUGIN_DIR/templates/spec-skeleton.md` via the Read tool (PLUGIN_DIR is the value extracted from `~/.pmcontext`). Write its content to `docs/superpowers/specs/YYYY-MM-DD-[feature]-design.md`. Do not write freeform prose — complete every field in the skeleton form.

**Step 3 — Fill the skeleton:**

- **`## Problem` and `## Goal`:** One paragraph each from Phase 2 findings.
- **`## Interfaces`:** One subsection per changed interface. Paste the exact current signature from the file read in Step 1 into `Before:`. Write the exact new signature into `After:`. For every type in `After:` that originates from a third-party library, take one of:
  - **Path A:** Output `[CONTEXT7] Fetching docs for <library> → done` — fetch context7 docs for the library now, use the result for the accurate type definition.
  - **Path B:** Output `[KNOWN] <library>/<API> — core stable API, training knowledge sufficient. No fetch.` — allowed only for React hooks, TypeScript built-ins, standard DOM APIs. Not allowed for version-sensitive APIs, configuration options, or detailed type hierarchies.
- **`## Edge Cases & Error States`:** Complete the table with at minimum: empty input, invalid input, external dependency failure.
- **`## Access-Control Matrix`:** One row per **role × resource** this feature touches, where a resource is a table, endpoint group, or file store. For each: what the role can read, what it can create/modify/delete, the ownership key that scopes it to its own rows, and where the check is enforced. Name resources exactly as the project already names them — `(Role, Resource)` is the merge key Phase 9 uses against the project-wide table in `CLAUDE.md`, so a typo silently creates a second row instead of updating the real one. Prefer database-level enforcement (e.g. an RLS policy) over app code — if it is app-code-only, say so, that is a finding. Answer the token-revocation question with a named mechanism. Never leave the table blank: a feature with no boundaries gets one explicit "public by design" row and a reason.

  Before writing the rows, read the `### Access Control` table in the project's `CLAUDE.md` if it exists. Any `(Role, Resource)` pair you are about to write that is already there is an existing boundary you are changing — write the new state in the spec and flag it now as `[RISK] widening/narrowing existing access: <role> on <resource>`. Do not wait for Phase 9 to discover it.
- **`## Expected Scale`:** Every row gets a named number. Use a real measurement where one exists (row counts from the database, traffic from logs); otherwise write the assumed number and mark it `assumed`. Flag any table that grows unbounded and any hot query without an index — both are Phase 5 inputs.
- **`## Out of Scope`:** At least one explicit exclusion.
- **`## Assumptions`:** Every assumption with a `file:line` or "confirmed with user" reference.

### Transition Checkpoint

Before writing any plan, verify against the codebase:
- Do any proposed APIs or types conflict with existing code?
- Is anything in the spec assumed without being verified against the actual codebase?

Report findings explicitly — do not summarize as "looks good." Fix any conflicts or unverified assumptions before proceeding.

**Phase 3 Self-Review Checklist** (run inline — fix issues before exit gate, no re-review needed):
- [ ] No field contains `[`, `TBD`, or `TODO`
- [ ] Every `After:` type is consistent with types used elsewhere in the spec
- [ ] Every `After:` type from a third-party library has taken Path A or Path B — no silent skip allowed
- [ ] Edge cases table has ≥ 3 rows covering: empty input, invalid input, external dep failure
- [ ] `Access-Control Matrix` has a row per role × resource touched, each with an `Ownership key` (or `—`) and an `Enforced by`, plus a token-revocation answer — no blanks
- [ ] Every `(Role, Resource)` pair already present in the project's `CLAUDE.md` access table is either unchanged or flagged `[RISK]` as a boundary change
- [ ] `Expected Scale` has a named number in every row, each marked `measured` or `assumed`
- [ ] `Out of Scope` has ≥ 1 entry
- [ ] Every assumption has a non-blank `Verified by` entry

**Exit gate:** Self-review checklist passed. No unresolved conflicts. User has approved. Write the Phase 3 gate and mark the task as completed:

```sql
UPDATE pm_sessions
SET phase_gates = phase_gates || jsonb_build_object(
    'phase_3', jsonb_build_object(
        'spec_verified', true,
        'no_conflicts', true,
        'sections_complete', jsonb_build_object(
            'interfaces', true,
            'edge_cases_table', true,
            'access_control_matrix', true,
            'expected_scale', true,
            'out_of_scope', true,
            'assumptions', true
        ),
        'self_review_passed', true,
        'approved_at', NOW()
    )
),
updated_at = NOW()
WHERE id = '<PLANNING_SESSION_ID>';
```

### Output

Save to `docs/superpowers/specs/`:

**1. Markdown spec (all tiers):**
`YYYY-MM-DD-[feature-name]-design.md` — structured prose covering behavior, interfaces, edge cases, and assumptions.

**2. HTML visual companion (full tier only):**
`spec-[feature-name].html` — self-contained styled file. Must include:
- Sticky sidebar navigation linking to each section
- Color-coded sections: behavior (blue), interfaces (green), edge cases (amber), assumptions (red)
- All assumptions highlighted with a visible warning style
- A checklist of exit gate items the user can tick off while reviewing

To review: `python3 -m http.server 8090` from the project root, then open `http://localhost:8090/docs/superpowers/specs/spec-[feature-name].html`

Skip the HTML companion if `<TIER>` = `standard`.

---

## Phase 4 — Plan Writing

Mark the Phase 4 task as in_progress.

Verify the Phase 3 gate was recorded:

```sql
SELECT (phase_gates->>'phase_3') IS NOT NULL AS gate_cleared
FROM pm_sessions WHERE id = '<PLANNING_SESSION_ID>';
```

If `gate_cleared = false`, output and stop:
```
[BLOCKED] Phase 3 gate not recorded. The spec must be verified and approved before writing the plan.
```

**Codebase Sync:**

Before writing any plan step, read every file listed in the spec's `## Interfaces` `Before:` blocks to confirm their current state. Also read any file identified in Phase 3 Step 1 that was not in the spec. Extract all third-party import statements from each file. Write a sync table into the plan file, placed after the plan header block (Goal / Architecture / Tech Stack / `---`) and before `## Task 1`:

```markdown
## Codebase Sync — YYYY-MM-DD

| File | Lines | Key symbols verified | Third-party imports |
|---|---|---|---|
| `path/to/file.ts` | 312 | `functionName(param: Type): ReturnType` | `react-query`, `zod` |
```

After building the sync table:
1. Merge all third-party imports found into `Libraries touched:` in the Session Launch section — auto-populating or extending the existing value
2. For each library now in `Libraries touched:`, take Path A (fetch context7) or Path B (explicit `[KNOWN]` self-certification) — same rules as Phase 3
3. Output `[AUTO] Libraries touched updated from imports: [list]` if new libraries were added

**Break the spec into steps:**

Break the verified spec into ordered, executable steps.

Each step must include:
- What code changes or actions are required
- The exit state after this step — is the codebase consistent or broken between steps?
- A **Verify:** block — required for every code-modifying step:

```markdown
**Verify:**
Run: `[exact command]`
Expected: `[exact output line or pattern — not "tests pass"]`
If instead: `[what failure looks like and what to check first]`
```

Every symbol referenced in a code snippet must appear in the codebase sync table above. If you write a function name or type that is not in the sync table, re-read the file to verify it exists before including it.

### Transition Checkpoint

Answer all six with specific findings — not "yes":
1. Is verification built in at each step, not just at the end?
2. Are tasks and steps grouped by what is independently vs. dependently testable?
3. Did you extract everything relevant — constraints, limitations, non-obvious edge cases?
4. Are there external dependencies the plan assumes exist but does not verify first?
5. Does the codebase sync table cover every file the plan touches?
6. Does every code-modifying step have a `Verify:` block with exact expected output (not "tests pass")?

Fix any issues found before proceeding.

**Exit gate:** All four questions answered with concrete findings. All issues resolved. User has approved. Write the Phase 4 gate and mark the task as completed:

```sql
UPDATE pm_sessions
SET phase_gates = phase_gates || jsonb_build_object(
    'phase_4', jsonb_build_object(
        'four_questions_answered', true,
        'codebase_sync_complete', true,
        'all_steps_verified', true,
        'approved_at', NOW()
    )
),
updated_at = NOW()
WHERE id = '<PLANNING_SESSION_ID>';
```

### Output

Save to `docs/superpowers/plans/`:

**1. Markdown plan (all tiers):**
`YYYY-MM-DD-[feature-name]-plan.md` — ordered steps with exit states and verification methods.

**2. HTML visual companion (full tier only):**
`plan-[feature-name].html` — self-contained styled file. Must include:
- Sticky sidebar navigation with phase links
- Color-coded phases: exploration (purple), spec (blue), plan (green), review (red), TDD (orange), implementation (teal)
- Each plan step as a card with: step number, action, exit state, verification method
- Dependency graph as an inline SVG diagram
- Checkpoint questions as a visible checklist
- External dependencies in a highlighted warning box

To review: `python3 -m http.server 8090` from the project root, then open `http://localhost:8090/docs/superpowers/plans/plan-[feature-name].html`

Skip the HTML companion if `<TIER>` = `standard`.

**3. Session Launch section (required — append to the Markdown plan file):**

```markdown
## Session Launch

Tier:
What this builds:
Codebase state going in:
Files the plan touches:
Libraries touched:
Key design decisions:
Gotchas:
Start here:
End here:
Mandatory context:
```

Fill every field before marking the plan approved. `Tier:` must be `standard` or `full` — `/pmcontext:execute` reads this to calibrate Phase 8 depth. `Libraries touched:` lists any external libraries or APIs, including those auto-detected from the codebase sync import scan — write `—` if none. `Mandatory context:` lists the spec file path and any type definition files read during the codebase sync that are not already in "Files the plan touches" — write `—` if none beyond the spec.

---

## Phase 5 — Adversarial Review

Mark the Phase 5 task as in_progress.

Verify the Phase 4 gate was recorded:

```sql
SELECT (phase_gates->>'phase_4') IS NOT NULL AS gate_cleared
FROM pm_sessions WHERE id = '<PLANNING_SESSION_ID>';
```

If `gate_cleared = false`, output and stop:
```
[BLOCKED] Phase 4 gate not recorded. The plan's four checkpoint questions must be answered and approved before the adversarial review.
```

Switch from generation mode to review mode. Goal: find problems, not defend the plan.

Three passes, all required on both tiers — Pass A against the plan, Pass B against the spec's `## Access-Control Matrix`, Pass C against the spec's `## Expected Scale`. Tier changes the depth of each, never whether it runs. Read the spec file now; Passes B and C are scored against it, not against memory of it.

---

## Pass A — Structural

---

### Standard tier — structural check

Answer both questions with specific findings:

1. **Intermediate states:** After each step, is the codebase consistent or broken? Walk through each step briefly.
2. **Dependency order:** Can each step run given only what precedes it? Identify any step that assumes something not yet built.

If either check fails → return to Phase 4 and fix, then re-check.
If both pass → write the gate and proceed.

---

### Full tier — adversarial review

Check:
- Trace each step's intermediate state — after this step, is the codebase consistent or broken?
- Draw the actual dependency graph — what must exist before each step can run?
- What did you observe in the codebase that is not yet documented in the plan?

**Loop-Back Decision:**

| Finding | Action |
|---|---|
| Surface fix — wrong step order, missing verification point | Return to Phase 4 |
| Architectural issue — wrong interface, broken dependency | Return to Phase 3 |
| Fundamental problem — wrong approach or wrong problem | Return to Phase 2 |

**Rollback rule:** If more than one-third of plan steps need reworking, do not patch. Restart from Phase 3.

---

## Pass B — Security Abuse

Attack the plan against the spec's `## Access-Control Matrix`. For each `(Role, Resource)` row the plan touches, ask what a hostile client does with it. Report each as PASS or a `[RISK]` with the specific row and plan step — never a summary.

| Check | The question | Fails when |
|---|---|---|
| **IDOR** | Role A requests role B's row by guessing its id — say, a `GET` on another user's comment id. What stops it? | The ownership key is not in the query's `WHERE`, or the check is a client-side filter |
| **Enforcement location** | Does the check run where `Enforced by` claims? Name the migration, policy, or middleware. | The row says a database policy but the plan only adds an app-code `if` — the next caller of that table skips it |
| **Unauthenticated reach** | Which new routes/handlers does the plan add, and which are reachable with no token? | A route serves a non-`anon` resource without an auth check |
| **Input validation** | Every new input crossing a trust boundary — validated server-side, or only in the form? | Validation exists only client-side, or a free-text field reaches a query unparameterized |
| **Ownership on write** | On create/update, is the owner taken from the session or from the request body? | The body supplies `author_id` — the client picks who it is |
| **Token revocation** | Does the plan honor the spec's stated mechanism? | A new long-lived credential appears with no way to revoke it |

**Standard tier:** cover only the `(Role, Resource)` rows this plan touches, one line of evidence each.
**Full tier:** all of the above, plus — every row the plan touches *indirectly* (a shared table, a reused handler, a widened query), and the abuse chain: what does a compromised `user` reach from here, and does any step move a check from the database into app code?

**Any row where the plan widens access** (`own only` → `all`, or a new `anon` row) is reported to the user here even when it is exactly what the plan intends.

---

## Pass C — Load

Attack the plan against the spec's `## Expected Scale`. Every finding names a number.

| Check | The question | Fails when |
|---|---|---|
| **Hot query indexing** | Each query the plan adds — which index serves it? Match against the spec's "hot queries needing an index" row. | A hot query has no index, or filters on a column the index does not lead with |
| **Growth** | Does the plan write to a table the spec marked unbounded? What bounds it — retention, pagination, archival? | Rows accumulate forever with no cap and no cleanup step |
| **Query shape** | Any scan or join the plan adds that grows with table size rather than page size? Any query inside a loop? | A per-row query in a loop, or an unpaginated list endpoint |
| **State location** | Does any new state live in process memory (cache, counter, session, upload buffer)? | It does — it dies on restart and is wrong the moment a second replica exists |
| **Peak ×10** | Take the spec's peak traffic number, multiply by ten. What breaks first? Name it. | Nothing is named — that means the pass was not actually run |

**Standard tier:** the five checks against the numbers already in the spec.
**Full tier:** the above, plus — where the spec's numbers are marked `assumed`, say which finding flips if the real number is 10× off; and state the first bottleneck with its rough breaking point rather than only naming it.

---

## Loop-back from Passes B and C

| Finding | Action |
|---|---|
| Plan step is missing or wrong — no index, missing auth check, ownership from body | Return to Phase 4 |
| The spec is wrong — matrix row does not match what the feature needs, scale number is not credible | Return to Phase 3, fix the spec, re-run the pass |
| The feature needs access or scale the project should not grant | Return to Phase 2 — this is a product decision, escalate to the user as `[RISK]` |

A Pass B or Pass C finding never gets patched inline without also fixing the spec section it contradicts. The spec is what Phase 9 merges into `CLAUDE.md` — leave it wrong and the wrong thing becomes the project's permanent record.

---

**Exit gate (both tiers):** Plan is structurally sound. No broken intermediate states. Dependency order correct. All assumptions surfaced and verified. Passes B and C run against the spec with every finding resolved or accepted by the user as a stated `[RISK]`. User has approved.

Before writing the gate, explicitly state to the user:
- Your loop-back decision: `none` OR `returned to Phase X because [reason], resolved as [resolution]`
- Confirmation that all intermediate states between steps are consistent
- Confirmation that the dependency order is correct
- **Pass B result:** every `(Role, Resource)` row checked, and for each finding — what it was and how it was resolved. Any access this plan widens, stated in plain language the PM can rule on (`[RISK] any signed-in user will be able to delete another user's comment — intended?`)
- **Pass C result:** the named answer to peak ×10 — what breaks first. If nothing was named, the pass did not run; run it.

Write the Phase 5 gate and mark the task as completed:

```sql
UPDATE pm_sessions
SET phase_gates = phase_gates || jsonb_build_object(
    'phase_5', jsonb_build_object(
        'loop_back_decision', '<none or description of what was fixed>',
        'intermediate_states_clean', true,
        'dependency_order_correct', true,
        'abuse_pass', jsonb_build_object(
            'rows_checked', <count of (Role, Resource) rows reviewed>,
            'findings', '<what Pass B found and how each was resolved, or "none">',
            'access_widened', '<role on resource: old -> new, accepted by user, or "none">'
        ),
        'load_pass', jsonb_build_object(
            'findings', '<what Pass C found and how each was resolved, or "none">',
            'first_bottleneck_at_10x', '<the named thing that breaks first>'
        ),
        'approved_at', NOW()
    )
),
updated_at = NOW()
WHERE id = '<PLANNING_SESSION_ID>';
```

Then update the session row with the plan path:

```sql
UPDATE pm_sessions
SET plan_path = '<plan_path>', plan_name = '<plan_name>', status = 'completed', updated_at = NOW()
WHERE id = '<PLANNING_SESSION_ID>';
```

---

## Context Window Rule

At approximately 70% context window usage, stop and say:
> *"We are approaching context limits. I will update the living work plan now so this session can be resumed without loss."*

Write the update so that a fresh session with no conversation history can resume immediately from the document alone.

---

## Living Doc Update

Mark the Living Doc Update task as in_progress.

Apply any updates surfaced during the planning session:
- **`CLAUDE.md`** — add new patterns, constraints, or conventions discovered during exploration or spec writing
- **`ROADMAP.md`** — update priorities or direction if they shifted during Phase 2 or Phase 5

If any new open decisions or risks surfaced during planning, update pm_state via `mcp__claude_ai_Supabase__execute_sql` with `project_id = <PROJECT_ID>`. Double any single quote inside the JSON values (`'` → `''`) before substituting:
```sql
INSERT INTO pm_state (project, open_decisions, active_risks, updated_at)
VALUES ('<project>', '<open_decisions_json>', '<active_risks_json>', NOW())
ON CONFLICT (project) DO UPDATE
SET
  open_decisions = EXCLUDED.open_decisions,
  active_risks   = EXCLUDED.active_risks,
  updated_at     = NOW();
```

Mark the Living Doc Update task as completed.

Output:
```
✓ Plan ready: docs/superpowers/plans/YYYY-MM-DD-[feature-name]-plan.md

Run /pmcontext:execute docs/superpowers/plans/YYYY-MM-DD-[feature-name]-plan.md to begin execution.
```
