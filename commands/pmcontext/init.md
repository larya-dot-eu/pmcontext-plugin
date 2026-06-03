---
description: One-time setup — connect Supabase, create tables, write config to ~/.pmcontext
---

## Prerequisite Check

Supabase MCP must be available. Attempt to use it. If unavailable, output and stop:
```
[BLOCKED] /pmcontext:init requires Supabase MCP
Install or configure the Supabase MCP server and try again.
```

## Step 1: Discover Supabase Projects

Use `mcp__claude_ai_Supabase__list_projects` to list all available projects.

**If 1 project found**, output:
```
Found 1 project: <name> (id: <id>, region: <region>)
Using this project for pmcontext. Confirm? (yes / no)
```
Wait for user confirmation. If "no", stop and ask user to specify which project to use.

**If multiple projects found**, output a numbered list:
```
Found N Supabase projects:
1. <name> (id: <id>, region: <region>)
2. <name> (id: <id>, region: <region>)
...

Which project should pmcontext use? Enter the number:
```
Wait for user selection. Use the chosen project's `id` as `<PROJECT_ID>` and its `name` as `<PROJECT_NAME>` for the rest of this command.

## Step 2: Write Config File

First, locate the pmcontext plugin installation directory via Bash tool:
```bash
find ~/.claude -name "plugin.json" 2>/dev/null | while IFS= read -r f; do
  if grep -q '"name": "pmcontext"' "$f" 2>/dev/null; then
    dirname "$(dirname "$f")"
    break
  fi
done
```

Note the output as `<PLUGIN_DIR>`. If the output is empty, output a warning and set `<PLUGIN_DIR>` to blank:
```
[WARN] Could not locate pmcontext plugin directory — template scaffolding will be unavailable.
Run /pmcontext:init again after confirming the plugin is installed.
```

Write the config file via Bash tool:
```bash
printf "SUPABASE_PROJECT_ID=<PROJECT_ID>\nPLUGIN_DIR=<PLUGIN_DIR>\n" > ~/.pmcontext
```

Verify the write succeeded:
```bash
cat ~/.pmcontext
```
Expected output includes `SUPABASE_PROJECT_ID=<PROJECT_ID>` and `PLUGIN_DIR=<PLUGIN_DIR>`.

If the file is missing or empty after this step, output and stop:
```
[ERROR] Failed to write ~/.pmcontext — check file permissions.
```

If `<PLUGIN_DIR>` is set, verify the templates are present:
```bash
ls "<PLUGIN_DIR>/templates/"
```
If `CONTEXT.md` or `ROADMAP.md` are missing from the output, warn:
```
[WARN] Plugin templates incomplete at <PLUGIN_DIR>/templates/ — some scaffolding may be unavailable.
```

## Step 3: Create Tables

Apply migration `create_pm_sessions` via `mcp__claude_ai_Supabase__apply_migration` with `project_id = <PROJECT_ID>`:

```sql
CREATE TABLE IF NOT EXISTS pm_sessions (
  id                    UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  project               TEXT        NOT NULL,
  plan_path             TEXT,
  plan_name             TEXT,
  session_type          TEXT        NOT NULL DEFAULT 'execution'
                                    CHECK (session_type IN ('planning', 'execution')),
  status                TEXT        NOT NULL DEFAULT 'active'
                                    CHECK (status IN ('active', 'paused', 'completed')),
  current_step          INTEGER     DEFAULT 1,
  total_steps           INTEGER,
  phase_gates           JSONB       NOT NULL DEFAULT '{}',
  started_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  closed_at             TIMESTAMPTZ,
  files_changed         TEXT,
  surface_nodes_affected TEXT,
  commands_run          TEXT,
  tests_skipped         TEXT,
  risky_assumptions     TEXT,
  manual_checks         TEXT
);
```

Apply migration `create_pm_state` via `mcp__claude_ai_Supabase__apply_migration` with `project_id = <PROJECT_ID>`:

```sql
CREATE TABLE IF NOT EXISTS pm_state (
  project          TEXT        PRIMARY KEY,
  open_decisions   JSONB       NOT NULL DEFAULT '[]'::jsonb,
  active_risks     JSONB       NOT NULL DEFAULT '[]'::jsonb,
  last_checkpoint  JSONB,
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

Both migrations use `CREATE TABLE IF NOT EXISTS` — safe to re-run on an already-configured machine.

## Step 4: Confirm Setup

Output:
```
✓ pmcontext initialized

  Project:    <PROJECT_NAME>
  ID:         <PROJECT_ID>
  Config:     ~/.pmcontext
  Plugin dir: <PLUGIN_DIR>
  Tables:     pm_sessions ✓   pm_state ✓

Run /pmcontext:start to begin your first session.
```

## Step 5: Update Project CLAUDE.md

Check whether the pmcontext workflow block already exists in the project's `CLAUDE.md`:
```bash
grep -q "## PM–Claude Workflow" CLAUDE.md 2>/dev/null && echo "exists" || echo "missing"
```

**If "exists":** output `✓ CLAUDE.md already contains PM–Claude Workflow block — skipped` and stop this step.

**If "missing" and `<PLUGIN_DIR>` is set:**
Append the template to the project's `CLAUDE.md` (creates the file if it does not exist):
```bash
cat "<PLUGIN_DIR>/templates/CLAUDE.md.example" >> CLAUDE.md
```
Output: `✓ CLAUDE.md updated`

**If "missing" and `<PLUGIN_DIR>` is blank:**
Output:
```
[WARN] Could not update CLAUDE.md — PLUGIN_DIR not set.
Run /pmcontext:init again after confirming the plugin is installed, or add the PM–Claude Workflow block manually.
```
