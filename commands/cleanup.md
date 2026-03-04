---
description: Clear session caches — by project, command, age, or everything
---

# Cleanup Sessions

This command manages and clears Flywheel session data stored in `~/.flywheel/projects/`. Sessions accumulate over time from `/fw:implement`, `/fw:debug`, `/fw:migrate`, `/fw:harden`, `/fw:test`, and `/fw:tdd` runs. Use this command to reclaim disk space and keep your workspace clean.

---

## Step 1: Detect Project & Show Status

**Detect current project:**
```bash
PROJECT_NAME="${FLYWHEEL_PROJECT:-$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")")}"
PROJECT_DIR="$HOME/.flywheel/projects/$PROJECT_NAME"
```

**Scan for session data:**

1. List all projects with session data:
   ```bash
   ls -d "$HOME/.flywheel/projects"/*/ 2>/dev/null
   ```

2. For the current project (and optionally all projects), count sessions per command:
   ```bash
   # For each command directory (implement, debug, migrate, harden, test, tdd, results)
   # Count the number of session directories and total size
   ```

3. Also check for legacy flat sessions (pre-project-isolation):
   ```bash
   # Check if ~/.flywheel/implement/, ~/.flywheel/debug/, etc. exist at the top level
   ```

**Display the status dashboard:**

```
🧹 Flywheel Session Status
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📁 Current project: <PROJECT_NAME>
   Location: ~/.flywheel/projects/<PROJECT_NAME>/

   | Command    | Sessions | Size    | Oldest          | Newest          |
   |------------|----------|---------|-----------------|-----------------|
   | implement  | 12       | 4.2 MB  | 2026-01-15      | 2026-02-19      |
   | debug      | 8        | 1.8 MB  | 2026-02-01      | 2026-02-18      |
   | tdd        | 5        | 2.1 MB  | 2026-02-10      | 2026-02-19      |
   | test       | 3        | 890 KB  | 2026-02-14      | 2026-02-17      |
   | migrate    | 1        | 320 KB  | 2026-02-12      | 2026-02-12      |
   | harden     | 2        | 1.1 MB  | 2026-02-16      | 2026-02-18      |
   | results    | 47       | 8.3 MB  | 2026-01-15      | 2026-02-19      |
   |------------|----------|---------|                                   |
   | Total      | 78       | 18.7 MB |                                   |

📁 All projects:
   | Project          | Sessions | Size    |
   |------------------|----------|---------|
   | flywheel-plugin  | 78       | 18.7 MB |
   | my-web-app       | 23       | 5.1 MB  |
   | api-service      | 45       | 12.3 MB |
   |------------------|----------|---------|
   | Total            | 146      | 36.1 MB |
```

If legacy flat sessions exist, show a note:
```
⚠️ Legacy sessions found at ~/.flywheel/ (pre-project-isolation)
   Run with [migrate-legacy] to move them under the current project.
```

---

## Step 2: Parse Cleanup Target

Parse the user's input after `/fw:cleanup`:

| Input | Effect |
|-------|--------|
| *(no argument)* | Show status dashboard (Step 1), then ask what to clean |
| `project` | Clear all sessions for the current project |
| `project <name>` | Clear all sessions for the named project |
| `all` | Clear all sessions across all projects |
| `<command>` | Clear sessions for a specific command (e.g., `implement`, `debug`, `results`) |
| `older <duration>` | Clear sessions older than duration (e.g., `older 7d`, `older 1m`, `older 2w`) |
| `results` | Clear only dispatch result files (the `results/` directory) |
| `migrate-legacy` | Move legacy flat sessions into the current project directory |
| `teams` | List and clean up stale agent team configs from `~/.claude/teams/` |

**Duration parsing:**
- `Nd` = N days (e.g., `7d` = 7 days)
- `Nw` = N weeks (e.g., `2w` = 14 days)
- `Nm` = N months (e.g., `1m` = 30 days)

---

## Step 3: Confirm & Execute

**Always confirm before deleting.** Show exactly what will be removed:

```
🧹 Cleanup Plan:

  Action: Delete all sessions for project "flywheel-plugin"
  Scope:  78 sessions across 7 commands
  Size:   18.7 MB will be freed
  Path:   ~/.flywheel/projects/flywheel-plugin/

  ⚠️ This is irreversible. Session files contain phase outputs,
     diagnoses, proposals, and reports from previous runs.

  [confirm]  — proceed with cleanup
  [preview]  — list every session that will be deleted
  [cancel]   — abort
```

- **confirm** → execute cleanup
- **preview** → show full list of session directories with dates and sizes, then ask again
- **cancel** → stop

### Execute cleanup

Based on the target:

**Clear by project:**
```bash
rm -rf "$HOME/.flywheel/projects/<PROJECT_NAME>"
```

**Clear by command:**
```bash
rm -rf "$HOME/.flywheel/projects/$PROJECT_NAME/<COMMAND>"
```

**Clear by age:**
```bash
# For each session directory, parse the timestamp from the directory name (YYYYMMDD-HHMMSS)
# Delete if older than the specified duration
find "$HOME/.flywheel/projects/$PROJECT_NAME" -mindepth 2 -maxdepth 2 -type d | while read dir; do
    dir_date=$(basename "$dir" | grep -oE '^[0-9]{8}' || echo "")
    # Compare with cutoff date and delete if older
done
```

**Clear all:**
```bash
rm -rf "$HOME/.flywheel/projects"
```

**Clear results only:**
```bash
rm -rf "$HOME/.flywheel/projects/$PROJECT_NAME/results"
```

**Migrate legacy sessions:**
```bash
# For each command directory at the flat level (implement, debug, etc.)
for cmd in implement debug migrate harden test tdd results; do
    if [[ -d "$HOME/.flywheel/$cmd" ]]; then
        mkdir -p "$HOME/.flywheel/projects/$PROJECT_NAME/$cmd"
        mv "$HOME/.flywheel/$cmd"/* "$HOME/.flywheel/projects/$PROJECT_NAME/$cmd/" 2>/dev/null
        rmdir "$HOME/.flywheel/$cmd" 2>/dev/null
    fi
done
```

**Clean up stale agent teams** (`teams` target):
```bash
# List all team configs
TEAMS_DIR="$HOME/.claude/teams"
if [[ -d "$TEAMS_DIR" ]]; then
    echo "🤝 Agent team configs found:"
    ls -la "$TEAMS_DIR"/ 2>/dev/null || echo "  (none)"

    # Check for orphaned tmux sessions from agent teams
    if command -v tmux &>/dev/null; then
        echo ""
        echo "Active tmux sessions (may include agent team sessions):"
        tmux ls 2>/dev/null || echo "  (no tmux sessions)"
    fi

    # Offer to remove stale team configs
    echo ""
    echo "Remove all team configs from $TEAMS_DIR? [confirm / cancel]"
    # On confirm:
    # rm -rf "$TEAMS_DIR"/*
fi
```

---

## Step 4: Report

After cleanup, show the result:

```
✅ Cleanup Complete

  Deleted: 78 sessions (18.7 MB)
  Scope:   project "flywheel-plugin"

  Remaining:
  | Project          | Sessions | Size    |
  |------------------|----------|---------|
  | my-web-app       | 23       | 5.1 MB  |
  | api-service      | 45       | 12.3 MB |
  |------------------|----------|---------|
  | Total            | 68       | 17.4 MB |
```

If everything was cleaned:
```
✅ Cleanup Complete — all Flywheel session data cleared (36.1 MB freed)
```

---

## Examples

```bash
# Show what's stored (dashboard only)
/fw:cleanup

# Clear everything for the current project
/fw:cleanup project

# Clear a specific project
/fw:cleanup project my-web-app

# Clear only implement sessions for current project
/fw:cleanup implement

# Clear only dispatch results (the raw agent outputs)
/fw:cleanup results

# Clear sessions older than 2 weeks
/fw:cleanup older 2w

# Clear sessions older than 30 days across ALL projects
/fw:cleanup all older 30d

# Move legacy flat sessions into current project
/fw:cleanup migrate-legacy

# Clean up stale agent team configs
/fw:cleanup teams

# Nuclear option — clear everything
/fw:cleanup all
```

---

## Error Handling

- **No sessions found**: Report "Nothing to clean — no sessions found for `<target>`."
- **Project not found**: List available projects and suggest the correct name
- **Permission denied**: Report the error and suggest checking file permissions
- **Legacy sessions detected**: Prompt the user to run `migrate-legacy` before cleanup
- **Disk space check fails**: Fall back to counting files instead of reporting sizes

---

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `FLYWHEEL_PROJECT` | `<git repo name>` | Override project name for session isolation |
