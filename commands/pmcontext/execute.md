---
description: Execute a plan file end-to-end with TDD, task tracking, and code review
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

The plan path is: $ARGUMENTS

If $ARGUMENTS is empty, output:
```
Usage: /pmcontext:execute <path-to-plan-file>
Example: /pmcontext:execute docs/superpowers/plans/2026-06-02-my-feature.md
```
and stop.

## Step 1: Read the Plan File

Read the plan file at the path provided in $ARGUMENTS. If the file does not exist, output:
```
[ERROR] Plan file not found: <path>
```
and stop.

## Step 2: Load Project Context

Read the following files from the project root if they exist (run checks in parallel via Bash tool):
```bash
test -f CONTEXT.md && echo "exists" || echo "missing"
test -f PROJECT_BRIEF.md && echo "exists" || echo "missing"
```

- **CONTEXT.md** — Node Model (Surface vs Core nodes). Use the `[BLAST RADIUS]` tag when a plan step changes a Core Node.
- **PROJECT_BRIEF.md** — Surface Node Inventory and Core Node Map. Use this to identify which Surface Nodes a plan step may affect.

If either file is missing, continue without it — do not block execution.

## Step 3: Parse the Session Launch Section

Find the `## Session Launch` section at the end of the plan file. Extract:
- **Tier** — `standard` or `full`. If missing or blank, default to `standard`. Set as `<TIER>`.
- **What this builds** — one sentence summary
- **Codebase state going in** — test count, branch, relevant state
- **Files the plan touches** — list of files
- **Libraries touched** — list of external libraries/APIs (blank or `—` means none)
- **Key design decisions** — resolved decisions
- **Gotchas** — things to watch for
- **Start here** — first action
- **End here** — success criteria

If the `## Session Launch` section is missing, warn:
```
[WARN] No ## Session Launch section found in this plan.
Context will be limited. Proceeding with plan execution.
```

## Step 4: Prerequisite Check

**Required — abort if missing:**

- Supabase MCP:
  ```
  [BLOCKED] /pmcontext:execute requires Supabase MCP
  ```
- `superpowers:executing-plans` skill:
  ```
  [BLOCKED] /pmcontext:execute requires superpowers:executing-plans
  Install: npx skills add superpowers
  ```
- `superpowers:test-driven-development` skill:
  ```
  [BLOCKED] /pmcontext:execute requires superpowers:test-driven-development
  Install: npx skills add superpowers
  ```
- context7 MCP — **only required if `Libraries touched` field is non-empty:**
  ```
  [BLOCKED] This plan touches external libraries. context7 MCP is required for current docs.
  Install or configure the context7 MCP server to continue.
  ```

**Recommended — warn and continue:**
- `superpowers:requesting-code-review`:
  `[WARN] superpowers:requesting-code-review not found — code review step will be skipped at session end`
- `superpowers:verification-before-completion`:
  `[WARN] superpowers:verification-before-completion not found — completion verification will be skipped`
- `superpowers:using-git-worktrees`:
  `[WARN] superpowers:using-git-worktrees not found — working directly on current branch`

## Step 5: Create Session Row

Detect the current project name: run `git rev-parse --show-toplevel 2>/dev/null | xargs basename | tr -cd 'a-zA-Z0-9_-'` via Bash tool. If not in a git repo, use `basename "$PWD" | tr -cd 'a-zA-Z0-9_-'`.

Count the total plan steps (checkbox items `- [ ]` in the plan file).

Run via `mcp__claude_ai_Supabase__execute_sql` with `project_id = <PROJECT_ID>`:
```sql
INSERT INTO pm_sessions (project, plan_path, plan_name, session_type, tier, status, current_step, total_steps, started_at, updated_at)
VALUES ('<project>', '<plan_path>', '<plan_name>', 'execution', '<TIER>', 'active', 1, <total_steps>, NOW(), NOW())
RETURNING id;
```
Note the returned `id` as `<SESSION_ID>`.

## Create Phase Tasks

Create all four phase tasks upfront so the full workflow is visible from the start. Use TaskCreate for each:

1. `Phase 6 — TDD Planning`
2. `Phase 7 — Implementation`
3. `Phase 8 — Post-Implementation Review`
4. `Phase 9 — Living Doc Update`

Note each task ID for use in the phases below.

---

## Phase 6 — TDD Planning

Mark the Phase 6 task as in_progress.

Before any implementation code is written, define the testing approach for this plan. Invoke the `superpowers:test-driven-development` skill to:
- Identify which interfaces need to change
- Agree on test priority order — critical paths first
- Design each component for testability: inject dependencies, return results instead of side effects, no hidden state

When the test approach and interface design are agreed with the user, write the Phase 6 gate and mark the task as completed:

```sql
UPDATE pm_sessions
SET phase_gates = phase_gates || jsonb_build_object(
    'phase_6', jsonb_build_object(
        'interfaces_agreed', true,
        'test_priority_defined', true,
        'approved_at', NOW()
    )
),
updated_at = NOW()
WHERE id = '<SESSION_ID>';
```

---

## Phase 7 — Implementation

Mark the Phase 7 task as in_progress.

Verify the Phase 6 gate was recorded before writing any implementation code:

```sql
SELECT (phase_gates->>'phase_6') IS NOT NULL AS gate_cleared
FROM pm_sessions WHERE id = '<SESSION_ID>';
```

If `gate_cleared = false`, output and stop:
```
[BLOCKED] Phase 6 gate not recorded. Interface design and test priority must be agreed before implementation begins.
```

Invoke the `superpowers:executing-plans` skill to execute the plan step-by-step. Before invoking, count the total plan steps (checkbox items `- [ ]` in the plan file). When creating a task for each plan step, prefix each task name with `[Ph.7 · N/total]` — for example `[Ph.7 · 3/8] Add JWT validation`. This makes the phase hierarchy visible in the flat task list alongside the Phase 6–9 tasks.

After completing each plan step, update Supabase via `mcp__claude_ai_Supabase__execute_sql` with `project_id = <PROJECT_ID>`:
```sql
UPDATE pm_sessions
SET current_step = <completed_step + 1>, updated_at = NOW()
WHERE id = '<SESSION_ID>';
```

If the session is interrupted before all steps are complete:
```sql
UPDATE pm_sessions
SET status = 'paused', updated_at = NOW()
WHERE id = '<SESSION_ID>';
```
Mark the Phase 7 task as in_progress (not completed) and stop. Resume with `/pmcontext:resume`.

When all plan steps are complete, write the Phase 7 gate and mark the task as completed:

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

Mark the Phase 8 task as in_progress.

Verify the Phase 7 gate was recorded:

```sql
SELECT (phase_gates->>'phase_7') IS NOT NULL AS gate_cleared
FROM pm_sessions WHERE id = '<SESSION_ID>';
```

If `gate_cleared = false`, output and stop:
```
[BLOCKED] Phase 7 gate not recorded. All implementation steps and tests must be complete before the review.
```

**Full tier only:** invoke an external code review before checking the items below.
- If `superpowers:requesting-code-review` is available — invoke it.
- Otherwise invoke the `code-review` skill if available.

**Standard tier:** skip the external code review — internal review only.

Check:
- Did the implementation match the plan? If not, document what changed and why.
- Did any new constraints or patterns surface that should be added to `CLAUDE.md`?
- Did any edge cases appear that were not in the spec?
- Does `ROADMAP.md` need updating?

Report findings to the user. Flag any recommended doc updates. Write the Phase 8 gate and mark the task as completed:

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

Mark the Phase 9 task as in_progress.

Verify the Phase 8 gate was recorded:

```sql
SELECT (phase_gates->>'phase_8') IS NOT NULL AS gate_cleared
FROM pm_sessions WHERE id = '<SESSION_ID>';
```

If `gate_cleared = false`, output and stop:
```
[BLOCKED] Phase 8 gate not recorded. The post-implementation review must be completed and reported before updating living docs.
```

Apply any doc updates flagged in Phase 8:
- **`CLAUDE.md`** — add new patterns or constraints established this session
- **`ROADMAP.md`** — update priorities or direction if they shifted

If new open decisions or risks surfaced during execution, update pm_state via `mcp__claude_ai_Supabase__execute_sql` with `project_id = <PROJECT_ID>`:
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

Mark the Phase 9 task as completed.

Output: `"Plan execution complete. Run /pmcontext:close to write the session receipt."`
