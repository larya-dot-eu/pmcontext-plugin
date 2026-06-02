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
- Run `git rev-parse --show-toplevel` via Bash tool, then take the basename.
- If not in a git repo, use the basename of the current working directory.
- Use this value as `<project>` in SQL WHERE clauses below.

## Prerequisite Check

**Required — abort if missing:**
- Supabase MCP: if unavailable, output and stop:
  ```
  [BLOCKED] /pmcontext:start requires Supabase MCP
  ```

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
```bash
grep -q "## PM–Claude Workflow" CLAUDE.md 2>/dev/null && echo "exists" || echo "missing"
```
If missing and `<PLUGIN_DIR>` is set:
```bash
cat "<PLUGIN_DIR>/templates/CLAUDE.md.example" >> CLAUDE.md
```
Output: `✓ Updated CLAUDE.md`

If missing and `<PLUGIN_DIR>` is blank:
- Output: `[WARN] CLAUDE.md pmcontext block missing and plugin templates unavailable — run /pmcontext:init to fix.`

## Load Context

**Step 1 — Read CONTEXT.md:** Read it if present. It defines the PM–Claude protocol and codebase tour instructions.

**Step 2 — Read PROJECT_BRIEF.md:** Read it if present.

**Step 3 — Read ROADMAP.md:** Read it if present.

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
This produces a Surface Node Inventory, Core Node Map, Test Strategy,
End-to-End Checkpoints, and Security Surface Audit — saved to PROJECT_BRIEF.md.
(yes / no)
```
If yes: follow the "What I Need From You: The Codebase Tour" section from CONTEXT.md. Write all five deliverables to `PROJECT_BRIEF.md`. Output: `✓ PROJECT_BRIEF.md created`

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
