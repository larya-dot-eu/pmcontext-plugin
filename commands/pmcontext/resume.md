---
description: Resume last paused or active session from where it left off
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
- Use this value as `<project>` in SQL WHERE clauses below.

## Prerequisite Check

**Required — abort if missing:**
- Supabase MCP: if unavailable, output and stop:
  ```
  [BLOCKED] /pmcontext:resume requires Supabase MCP
  ```
- `superpowers:executing-plans`:
  ```
  [BLOCKED] /pmcontext:resume requires superpowers:executing-plans
  Install: npx skills add superpowers
  ```
- `superpowers:test-driven-development`:
  ```
  [BLOCKED] /pmcontext:resume requires superpowers:test-driven-development
  Install: npx skills add superpowers
  ```

**Recommended — warn and continue:**
- `superpowers:requesting-code-review`:
  `[WARN] superpowers:requesting-code-review not found — code review will be skipped`
- `superpowers:verification-before-completion`:
  `[WARN] superpowers:verification-before-completion not found`
- `superpowers:using-git-worktrees`:
  `[WARN] superpowers:using-git-worktrees not found — working directly on current branch`

## Find Last Session

Run via `mcp__claude_ai_Supabase__execute_sql` with `project_id = <PROJECT_ID>`:
```sql
SELECT id, plan_name, plan_path, tier, current_step, total_steps, status, phase_gates, updated_at
FROM pm_sessions
WHERE project = '<project>'
  AND status IN ('active', 'paused')
ORDER BY updated_at DESC
LIMIT 1;
```

**If no row found:**
```
No active or paused session found for project: <project>
Run /pmcontext:start to orient, or /pmcontext:execute <path> to start a new plan.
```
Stop.

**If row found:** note `plan_path`, `current_step`, `total_steps`, `id` as `<SESSION_ID>`, `tier` as `<TIER>` (default `standard` if blank), `phase_gates` as `<PHASE_GATES>`.

**Determine resume point from `phase_gates`:**
- `phase_7` gate exists AND `phase_8` gate exists → resume from **Phase 9**
- `phase_7` gate exists, no `phase_8` gate → resume from **Phase 8**
- No `phase_7` gate → resume from **Phase 7**, step `<current_step>`

## Read Plan File

Read the plan file at `plan_path`. If the file does not exist:
```
[ERROR] Plan file not found: <plan_path>
The session record references a file that no longer exists.
Run /pmcontext:execute <new-plan-path> to start a new session.
```
Stop.

## Load Project Context

Read the following files from the project root if they exist (run checks in parallel via Bash tool):
```bash
test -f CONTEXT.md && echo "exists" || echo "missing"
test -f PROJECT_BRIEF.md && echo "exists" || echo "missing"
```

- **CONTEXT.md** — Node Model (Surface vs Core nodes). Use the `[BLAST RADIUS]` tag when a plan step changes a Core Node.
- **PROJECT_BRIEF.md** — Surface Node Inventory and Core Node Map. Use this to identify which Surface Nodes a plan step may affect.

If either file is missing, continue without it — do not block resumption.

## Phase 7 — Resume Implementation

Skip to Phase 8 if the `phase_7` gate already exists in `<PHASE_GATES>`.

Output:
```
Resuming: <plan_name>  [<TIER> tier]
Continuing Phase 7 from step <current_step> of <total_steps>
```

If Phase 6 gate is missing from `<PHASE_GATES>`, warn:
```
[WARN] Phase 6 gate not recorded — TDD planning may have been incomplete before this session was paused. Continuing with caution.
```

Check `Libraries touched` in the plan's `## Session Launch` section. If non-empty and context7 MCP is unavailable:
```
[BLOCKED] This plan touches external libraries. context7 MCP required.
```
Stop.

Count total plan steps (checkbox items `- [ ]`). When creating tasks for remaining steps, prefix each with `[Ph.7 · N/total]` to keep phase context visible in the task list.

Invoke the `superpowers:executing-plans` skill, starting from step `<current_step>`.

After completing each step, update Supabase via `mcp__claude_ai_Supabase__execute_sql` with `project_id = <PROJECT_ID>`:
```sql
UPDATE pm_sessions
SET current_step = <completed_step + 1>, updated_at = NOW()
WHERE id = '<SESSION_ID>';
```

If interrupted again before all steps complete:
```sql
UPDATE pm_sessions
SET status = 'paused', updated_at = NOW()
WHERE id = '<SESSION_ID>';
```
Stop. Resume with `/pmcontext:resume`.

When all steps are complete, write the Phase 7 gate:
```sql
UPDATE pm_sessions
SET phase_gates = phase_gates || jsonb_build_object(
    'phase_7', jsonb_build_object(
        'all_steps_complete', true,
        'all_tests_passing', true,
        'approved_at', NOW()
    )
),
updated_at = NOW()
WHERE id = '<SESSION_ID>';
```

---

## Phase 8 — Post-Implementation Review

Skip to Phase 9 if the `phase_8` gate already exists in `<PHASE_GATES>`.

Verify Phase 7 gate:
```sql
SELECT (phase_gates->>'phase_7') IS NOT NULL AS gate_cleared
FROM pm_sessions WHERE id = '<SESSION_ID>';
```
If `gate_cleared = false`, output and stop:
```
[BLOCKED] Phase 7 gate not recorded. All implementation steps and tests must be complete before review.
```

**Full tier only:** invoke external code review before the checks below.
- If `superpowers:requesting-code-review` is available — invoke it.
- Otherwise invoke the `code-review` skill if available.

**Standard tier:** internal review only.

Check:
- Did the implementation match the plan? Document what changed and why.
- Did any new constraints or patterns surface that should be added to `CLAUDE.md`?
- Did any edge cases appear that were not in the spec?
- Does `ROADMAP.md` need updating?

Report findings to the user. Write the Phase 8 gate:
```sql
UPDATE pm_sessions
SET phase_gates = phase_gates || jsonb_build_object(
    'phase_8', jsonb_build_object(
        'review_complete', true,
        'approved_at', NOW()
    )
),
updated_at = NOW()
WHERE id = '<SESSION_ID>';
```

---

## Phase 9 — Living Doc Update

Verify Phase 8 gate:
```sql
SELECT (phase_gates->>'phase_8') IS NOT NULL AS gate_cleared
FROM pm_sessions WHERE id = '<SESSION_ID>';
```
If `gate_cleared = false`, output and stop:
```
[BLOCKED] Phase 8 gate not recorded. The post-implementation review must be completed before updating living docs.
```

Apply any doc updates flagged in Phase 8:
- **`CLAUDE.md`** — add new patterns or constraints established this session
- **`ROADMAP.md`** — update priorities or direction if they shifted

If new open decisions or risks surfaced, update pm_state via `mcp__claude_ai_Supabase__execute_sql` with `project_id = <PROJECT_ID>`:
```sql
INSERT INTO pm_state (project, open_decisions, active_risks, updated_at)
VALUES ('<project>', '<open_decisions_json>', '<active_risks_json>', NOW())
ON CONFLICT (project) DO UPDATE
SET
  open_decisions = EXCLUDED.open_decisions,
  active_risks   = EXCLUDED.active_risks,
  updated_at     = NOW();
```

Update the session row:
```sql
UPDATE pm_sessions
SET status = 'active', current_step = <total_steps>, updated_at = NOW()
WHERE id = '<SESSION_ID>';
```

Output: `"Plan execution complete. Run /pmcontext:close to write the session receipt."`
