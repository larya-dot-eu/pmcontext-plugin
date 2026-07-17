---
description: Orient session — scaffold missing files, load project context, surface decisions/risks, suggest next action
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

If `PLUGIN_DIR` is blank, warn and continue (scaffolding will be limited):
```
[WARN] PLUGIN_DIR not set — run /pmcontext:init to restore full configuration.
```

Detect the current project name:
- Run `git rev-parse --show-toplevel 2>/dev/null | xargs basename | tr -cd 'a-zA-Z0-9_-'` via Bash tool.
- If not in a git repo, run `basename "$PWD" | tr -cd 'a-zA-Z0-9_-'` instead.
- Use this value as `<project>` in SQL WHERE clauses below.

## Prerequisite Check

**Required — abort if missing:**
- Supabase MCP: if unavailable, output and stop:
  ```
  [BLOCKED] /pmcontext:start requires Supabase MCP
  ```

> **Supabase MCP tool names:** `mcp__claude_ai_Supabase__*` below assumes the common Supabase MCP install. If your server uses a different prefix, call the equivalent tool from whatever Supabase MCP is available — same SQL, same parameters.

**Recommended — warn and continue if missing:**
- `superpowers:brainstorming`:
  `[WARN] superpowers:brainstorming not found — ROADMAP creation and brainstorming unavailable`
- `superpowers:writing-plans`:
  `[WARN] superpowers:writing-plans not found — plan writing workflow unavailable`

## Scaffold Missing Files

Run all three checks in parallel via the Bash tool.

**Check 1 — CONTEXT.md:**
```bash
test -f CONTEXT.md && echo "exists" || echo "missing"
```
If missing and `<PLUGIN_DIR>` is set:
- Read the template via the Read tool at `<PLUGIN_DIR>/templates/CONTEXT.md`
- Write its content to `CONTEXT.md` in the project root
- Output: `✓ Created CONTEXT.md`

If missing and `<PLUGIN_DIR>` is blank:
- Output: `[WARN] CONTEXT.md missing and plugin templates unavailable — create it manually.`

**Check 2 — PROJECT_BRIEF.md:**
```bash
test -f PROJECT_BRIEF.md && echo "exists" || echo "missing"
```
If missing: set `<tour_needed> = true`

**Check 3 — ROADMAP.md:**
```bash
test -f ROADMAP.md && echo "exists" || echo "missing"
```
If missing: set `<roadmap_needed> = true`

**Check 4 — CLAUDE.md pmcontext block:**

The workflow block is versioned. It is the PM's description of their own job at each gate, so a stale block means the human is following instructions the commands no longer match.

```bash
grep -q "## PM–Claude Workflow" CLAUDE.md 2>/dev/null && echo "block:present" || echo "block:absent"
grep -oE "pmcontext:block-start v[0-9]+" CLAUDE.md 2>/dev/null | head -1
grep -oE "pmcontext:block-start v[0-9]+" "<PLUGIN_DIR>/templates/CLAUDE.md.example" 2>/dev/null | head -1
```

The third command is the version the plugin ships — never hardcode it here, always read it from the template.

| State | Action |
|---|---|
| `block:absent`, PLUGIN_DIR set | Append the template: `cat "<PLUGIN_DIR>/templates/CLAUDE.md.example" >> CLAUDE.md` → `✓ Updated CLAUDE.md` |
| `block:absent`, PLUGIN_DIR blank | `[WARN] CLAUDE.md pmcontext block missing and plugin templates unavailable — run /pmcontext:init to fix.` |
| Installed version == shipped version | Nothing. Do not mention it. |
| Installed version < shipped version | **Offer the upgrade** (below) |
| `block:present` but no version marker | Legacy block, predates versioning — **offer the upgrade**, treating the installed version as `v1` |
| PLUGIN_DIR blank and block present | Skip the version check silently — nothing to compare against |

**Offering the upgrade:**

Read the installed block and the shipped template. State plainly what the PM is missing — the actual differences, not "there is an update". Then:

```
[UPGRADE] Your CLAUDE.md workflow block is <v1 | vN>; the plugin ships <vN>.

  Missing from yours:
  <the real differences, in PM language — e.g. "the /pmcontext:deploy command
   and its gates", "Phase 3 now asks you to review an access-control matrix">

  Only the text between the pmcontext markers is rewritten, in place — the rest
  of CLAUDE.md keeps its content and its order. CLAUDE.md.bak is written first.
  If you edited anything inside the markers, those edits are lost.

  Upgrade the block? (yes / no / show me)
```

`show me` → print the differences in full, then ask again. `no` → continue the session; do not nag further this session.

**On yes:**

```bash
cp CLAUDE.md CLAUDE.md.bak
```

*If the installed block has markers* — replace the marked region **in place**, so the block keeps its position in the file:
```bash
awk -v tpl="<PLUGIN_DIR>/templates/CLAUDE.md.example" '
  /<!-- pmcontext:block-start/ {skip=1; while ((getline line < tpl) > 0) print line; close(tpl)}
  !skip {print}
  /<!-- pmcontext:block-end/ {skip=0}
' CLAUDE.md > CLAUDE.md.tmp && mv CLAUDE.md.tmp CLAUDE.md
```
The new block is printed at the old block's position and the old lines are skipped — content before *and* after the markers keeps its original order. (Appending instead would silently move the block to the end of the file, past anything the user wrote below it.)

*If the installed block is legacy (no markers)* — the end of the block cannot be located by marker, so check what follows the heading before touching anything:
```bash
awk '/^## PM–Claude Workflow/{found=1; next} found && /^## /{print "content-after-block"; exit}' CLAUDE.md
```
- **No output** — the block runs from its heading to end of file (how `init`/`start` originally appended it). Safe to replace:
  ```bash
  awk '/^## PM–Claude Workflow/{exit} {print}' CLAUDE.md > CLAUDE.md.tmp
  cat "<PLUGIN_DIR>/templates/CLAUDE.md.example" >> CLAUDE.md.tmp
  mv CLAUDE.md.tmp CLAUDE.md
  ```
- **`content-after-block`** — something was added after the block and its end is ambiguous. **Do not guess.** Output:
  ```
  [SKIP] Your workflow block has content after it, so I cannot tell where the block
  ends. Nothing was changed. To upgrade by hand: delete everything from
  "## PM–Claude Workflow" down to (but not including) the next "## " heading, then
  append <PLUGIN_DIR>/templates/CLAUDE.md.example.
  ```

Then confirm what happened:
```bash
grep -c "## PM–Claude Workflow" CLAUDE.md
```
Must print `1`. Anything else means the block was duplicated or lost — restore immediately with `mv CLAUDE.md.bak CLAUDE.md` and report the failure. Otherwise output `✓ CLAUDE.md workflow block upgraded to <vN> (backup: CLAUDE.md.bak)`.

## Load Context

**Step 0 — Read CLAUDE.md:** Run `test -f CLAUDE.md && echo "exists" || echo "missing"` via Bash. Read it if present — architecture rules and conventions.

**Step 1 — Read CONTEXT.md:** Read it if present. It defines the Node Model (Surface vs Core nodes).

**Step 2 — Read PROJECT_BRIEF.md:** Read it if present.

**Step 3 — Read ROADMAP.md:** Read it if present.

Output confirmation banner after Steps 0–3 complete:
```
[CONTEXT LOADED]
  CLAUDE.md     ✓     (or [missing])
  CONTEXT.md    ✓     (or [missing])
  ROADMAP.md    ✓     (or [missing])
```

**Step 4 — Query pm_state** via `mcp__claude_ai_Supabase__execute_sql` with `project_id = <PROJECT_ID>`:
```sql
SELECT open_decisions, active_risks, last_checkpoint
FROM pm_state
WHERE project = '<project>';
```

**Step 5 — Query pm_sessions** via `mcp__claude_ai_Supabase__execute_sql` with `project_id = <PROJECT_ID>`:
```sql
SELECT id, plan_name, plan_path, current_step, total_steps, status, updated_at
FROM pm_sessions
WHERE project = '<project>'
  AND status IN ('active', 'paused')
ORDER BY updated_at DESC
LIMIT 1;
```

## First-Time Setup Prompts

Handle any missing files before presenting the session output. Present both prompts together if both are missing.

**If `<tour_needed>` is true:**
```
No PROJECT_BRIEF.md found. Run the full codebase tour now?
Produces: Surface Node Inventory, Core Node Map, Test Strategy,
End-to-End Checkpoints, and Security Surface Audit — saved to PROJECT_BRIEF.md.
(yes / no)
```
If yes, read the codebase and produce all five deliverables, then write to `PROJECT_BRIEF.md`:

**1. Surface Node Inventory** — every user-facing feature or output:
- What it does (1 sentence, plain language — no code terms)
- How the PM can verify it: input → expected output, human-readable
- Stability: `stable` / `fragile` / `untested`

**2. Core Node Map** — key technical layers beneath the Surface nodes:
- What it does
- Which Surface nodes depend on it
- Known fragility or risks

**3. Test Strategy** — one test per Surface node at three levels (happy path, edge case, error path):
- `GIVEN` — input or starting state
- `WHEN` — the trigger
- `THEN` — observable result (what the PM sees, not internal behavior)
- `PASS if` / `FAIL if` — binary, unambiguous
- Behavior-focused, not implementation-focused

**4. End-to-End Checkpoints** — 3–5 tests covering the highest-risk Surface nodes:
- Single copy-pasteable command
- Output is a clear PASS/FAIL readable in 30 seconds
- Not tied to any specific internal implementation detail

**5. Security Surface Audit** — every point where external input is accepted, secrets are handled, or access control is decided:
- Risk rating: 🟢 Low / 🟡 Medium / 🔴 High
- Plain-language explanation of the actual risk to the PM, not what the code does

Output: `✓ PROJECT_BRIEF.md created`

**If `<roadmap_needed>` is true:**
```
No ROADMAP.md found. Create one now via brainstorming?
The structure guide is at: <PLUGIN_DIR>/templates/ROADMAP.md
(yes / no)
```
If yes:
- Read `<PLUGIN_DIR>/templates/ROADMAP.md` via the Read tool
- Invoke the `superpowers:brainstorming` skill with the template structure as the guide
- After brainstorming, write the agreed ROADMAP to `ROADMAP.md` in the project root
- Output: `✓ ROADMAP.md created`

## Output

Present in this order:

1. **Project + ROADMAP state** — 1–2 sentence summary from ROADMAP.md, or "No ROADMAP.md found."
2. **Surface Nodes** — if PROJECT_BRIEF.md exists, list each Surface Node in one line. If absent: "No PROJECT_BRIEF.md — run /pmcontext:start to generate one."
3. **Open decisions** — list each item from the `open_decisions` array, or "None."
4. **Active risks** — list each item from `active_risks` array, or "None."
5. **Last checkpoint** — from `last_checkpoint` field, or "None run yet."
6. **Paused session** — if Step 5 returned a row:
   `⚠ Paused session: <plan_name> at step <current_step>/<total_steps> — run /pmcontext:resume to continue`

## Suggest Next Action

- Paused session found → "Run /pmcontext:resume to continue, or /pmcontext:execute <path> to start a new plan."
- Open decisions exist → "There are open decisions waiting for your review before starting new work."
- Clean state → "No active session. Ready to brainstorm or execute a plan (/pmcontext:execute <path>)."
