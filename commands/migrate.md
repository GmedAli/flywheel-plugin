---
description: Framework, dependency, and API migration with rollback safety and validation gates
---

# Migration Workflow

> **Persona active:** `fw-migration-engineer` — precision migration specialist. Batches changes by risk (🟢 safe → 🟡 moderate → 🔴 breaking), requires a rollback plan before any batch runs, and stops at validation gate failures — never auto-continues past a broken build.

This command runs a structured 6-phase workflow to migrate existing code — framework upgrades, dependency version bumps, API changes, and language modernization. Claude orchestrates specialized agents at each phase. **No code is changed until you approve the migration manifest.**

---

## Step 0: Parse Input & Detect Scope

Parse the user's input:
- **Migration target**: the full text after `/fw:migrate`
- If no description provided, ask: *"What would you like to migrate? Examples: 'React 18 → 19', 'Express to Fastify', 'Jest to Vitest', 'upgrade all dependencies'"*

**Detect scope** from keywords in the description:

| Scope | Trigger words | Effect |
|-------|--------------|--------|
| `patch` | bump, update, upgrade dependency, version | Skip Phase 1 Gemini research, smaller batches |
| `minor` | migrate, switch, replace, upgrade framework | All phases |
| `major` | rewrite, modernize, overhaul, full migration | All phases + deeper research + smaller batch sizes |

Show the detected scope:
```
🔄 Migration: <description>
📐 Scope detected: MINOR — running full workflow
```

**Create session directory (per-project isolation):**
```bash
PROJECT_NAME="${FLYWHEEL_PROJECT:-$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")")}"
SESSION_DIR="$HOME/.flywheel/projects/$PROJECT_NAME/migrate/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$SESSION_DIR"
```

Save `$SESSION_DIR/00-session.md` with:
- Migration description
- Scope
- Start timestamp
- Git branch (run `git branch --show-current`)
- Working directory

---

## Team Configuration

> **Mode**: `team` when agent teams enabled AND scope is `minor` or `major`; `sequential` for `patch`
> **Template**: `parallel-migration-research` (from config/team-templates.yaml)
> **Minimum scope**: `minor` — skip teams for patch-level bumps
> **Detection**: `scripts/team-detect.sh`

| Role | Persona | Task | Parallel With |
|------|---------|------|---------------|
| framework-researcher | fw-researcher | Official migration guide + breaking changes research | codebase-analyzer |
| codebase-analyzer | fw-migration-engineer | Codebase impact analysis (affected files + patterns) | framework-researcher |

Both run simultaneously. Lead synthesizes before Phase 2 planning.

---

## Phase 1: Research Breaking Changes 🌐

> *Research and codebase inventory — parallel in team mode, sequential otherwise*
> **Skipped for `patch` scope**

**Goal:** Understand what's changing, what breaks, and what the official migration path is.

### 1a — Codebase Inventory (Claude, always runs)

You (Claude) scan the current project for:
- Current versions of the migration target (check package.json, go.mod, Cargo.toml, requirements.txt, etc.)
- All imports and usage patterns of the target library/framework (grep for relevant terms)
- Configuration files that reference the target (webpack, vite, tsconfig, etc.)
- Test files covering the affected areas
- Count of affected files and estimated blast radius

Summarise findings in `$SESSION_DIR/01-inventory.md`.

**Detect agent teams availability** (for minor + major scope):
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/team-detect.sh" 2>&1
```
Set `TEAM_MODE=true` if available and scope is `minor` or `major`.

### 1b — Ecosystem Research (minor + major only)

**[TEAM MODE — framework-researcher + codebase-analyzer run in parallel with Phase 1a]**

If `TEAM_MODE=true`:
```
Create an agent team for this migration session.

Spawn two research teammates simultaneously (alongside Phase 1a codebase inventory):

Teammate 1 — 'framework-researcher':
PERSONA IDENTITY: <contents of agents/personas/fw-researcher.md>
MIGRATION TARGET: <MIGRATION_DESCRIPTION>

TASK:
Research the migration path. Use Context7 first for the target technology.

Gather:
1. Official migration guide — step-by-step from maintainers
2. Breaking changes — every API, behaviour, or config change
3. Deprecated features — what's removed and what replaces it
4. Known pitfalls — community-reported gotchas and workarounds
5. Codemods or automated tooling available
6. Dependency compatibility — peer dep version requirements

Save to: <SESSION_DIR>/01-research.md

Teammate 2 — 'codebase-analyzer':
PERSONA IDENTITY: <contents of agents/personas/fw-migration-engineer.md>
MIGRATION TARGET: <MIGRATION_DESCRIPTION>

TASK:
Analyze the codebase for migration impact.

Scan for:
- Current versions of the migration target
- All imports and usage patterns (grep for relevant terms)
- Configuration files that reference the target
- Test files covering affected areas
- Count of affected files and estimated blast radius

Save to: <SESSION_DIR>/01-inventory.md
```

Wait for both teammates and Phase 1a to complete. Lead synthesizes all findings before Phase 2.
Cleanup at end of session: `"Clean up the team. Shut down all teammates first."`

---

**[SEQUENTIAL MODE — fallback when agent teams disabled or scope is patch]**

**Context7 pre-enrichment** — before dispatching to Gemini, gather official migration documentation:

1. Identify the migration target technology (e.g., "React", "Express", "Prisma") and version range
2. Call `mcp__context7__resolve-library-id` for the target technology
3. Call `mcp__context7__query-docs` with query: "Migration guide for <TARGET>. Breaking changes, deprecated APIs, and upgrade steps from <SOURCE_VERSION> to <TARGET_VERSION>"
4. If Context7 returns results, prepend them to the Gemini prompt as `OFFICIAL DOCUMENTATION CONTEXT`
5. If Context7 fails or returns nothing, skip silently and proceed without enrichment

**Run Gemini:**
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh" "gemini" "OFFICIAL DOCUMENTATION CONTEXT (via Context7):
<Context7 migration docs, or omit this section if none>

---

Research the migration path for: <MIGRATION_DESCRIPTION>.

Focus on:
1. Official migration guide — step-by-step instructions from the maintainers
2. Breaking changes — every API, behaviour, or config change between versions
3. Deprecated features — what's removed and what replaces it
4. Known pitfalls — community-reported gotchas, regressions, and workarounds
5. Codemods or automated tooling — official or community migration scripts
6. Dependency compatibility — which peer dependencies need version bumps

Be specific. Include version numbers, API names, and concrete examples."
```

Save output to `$SESSION_DIR/01-research.md`.

---

*(End of sequential mode fallback for Phase 1b)*

### Phase 1 Summary

Print:
```
✅ Phase 1 Complete — Research
   Inventory: <N> files use the target, <key patterns noted>
   Breaking changes: <top 3 breaking changes from Gemini>
   Codemods available: <yes/no — with names if yes>
```

---

## Phase 2: Build Migration Manifest 📋

> *Codex scans the codebase and produces a file-by-file change map*

**Goal:** Produce an exhaustive manifest of every change needed, categorised by risk.

Run Codex:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh" "codex" "You are a migration specialist. Based on the following context, produce a detailed migration manifest.

MIGRATION TARGET: <MIGRATION_DESCRIPTION>

CODEBASE INVENTORY:
<contents of 01-inventory.md>

BREAKING CHANGES & MIGRATION GUIDE:
<contents of 01-research.md, or 'N/A for patch scope'>

Produce a manifest with this exact structure:

## Migration Manifest

### Batch 1: Safe Changes (no behavioural impact)
| File | Change | Risk | Description |
|------|--------|------|-------------|
| ... | UPDATE | 🟢 Low | ... |

### Batch 2: Moderate Changes (localised behavioural impact)
| File | Change | Risk | Description |
|------|--------|------|-------------|
| ... | MODIFY | 🟡 Medium | ... |

### Batch 3: Breaking Changes (cross-module or architectural impact)
| File | Change | Risk | Description |
|------|--------|------|-------------|
| ... | REWRITE | 🔴 High | ... |

### Configuration Changes
| File | Change | Description |
|------|--------|-------------|
| ... | UPDATE | ... |

### Dependency Changes
| Package | Current | Target | Notes |
|---------|---------|--------|-------|
| ... | x.x.x | y.y.y | ... |

For each file, specify the EXACT changes needed — old API → new API, old pattern → new pattern.
Be exhaustive. Missing a file means a broken build." <AFFECTED_FILES_FROM_INVENTORY>
```

Save output to `$SESSION_DIR/02-manifest.md`.

Print:
```
✅ Phase 2 Complete — Migration Manifest
   Batch 1 (safe): <N> files
   Batch 2 (moderate): <N> files
   Batch 3 (breaking): <N> files
```

---

## Phase 3: Risk Assessment & User Gate ⛔

**This is a hard stop. No code is changed until you approve.**

You (Claude) review the manifest and produce a risk summary. Display it to the user:

```markdown
# 🔄 Migration Plan: <MIGRATION_TARGET>

## Risk Summary

| Metric | Value |
|--------|-------|
| Total files affected | <N> |
| Safe changes (Batch 1) | <N> files |
| Moderate changes (Batch 2) | <N> files |
| Breaking changes (Batch 3) | <N> files |
| Config changes | <N> files |
| Dependency changes | <N> packages |

## High-Risk Items ⚠️

<List any changes that could cause:
- Data loss or corruption
- Breaking changes to public APIs consumed by external services
- Changes to database schemas or migrations
- Removal of features users depend on>

## Recommended Approach

<Your recommendation: run all batches? Skip batch 3 for manual review? Run codemods first?>

## Rollback Strategy

<How to undo if something breaks:
- Git: `git stash` before starting, `git checkout .` to revert
- Dependencies: keep lockfile backup>
```

Then ask:
```
📋 Migration manifest ready. How would you like to proceed?

  [approve]    — execute all batches in order (safe → moderate → breaking)
  [batch N]    — execute only batch N (e.g., "batch 1" for safe changes only)
  [modify]     — tell me what to change in the manifest
  [cancel]     — exit without changes
```

- **approve** → continue to Phase 4 (all batches)
- **batch N** → continue to Phase 4 (only the specified batch)
- **modify** → update manifest, repeat Phase 3
- **cancel** → print "Migration cancelled. Session saved to `$SESSION_DIR`." and stop

---

## Phase 4: Execute Migration 🛠️

> *Codex applies changes batch by batch with validation between each*

**Goal:** Apply the migration incrementally, validating after each batch.

**Before starting, create a restore point:**
```bash
git stash push -m "flywheel-migrate-backup-$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
```

### For each approved batch (1 → 2 → 3):

**4a — Apply changes:**
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh" "codex" "Apply the following migration changes exactly as specified. Follow existing code style and patterns.

MIGRATION: <MIGRATION_DESCRIPTION>

CHANGES TO APPLY (Batch <N>):
<batch N rows from 02-manifest.md>

CODEBASE CONTEXT:
<contents of 01-inventory.md>

Requirements:
- Apply each change precisely as described in the manifest
- Preserve existing code formatting and style
- Update imports, type references, and configuration consistently
- Do NOT make changes outside the manifest scope
- If a change requires a file that doesn't exist, flag it instead of creating it" <FILES_IN_THIS_BATCH>
```

**4b — Validate batch:**

After each batch, run validation checks:
1. **Syntax check** — run the project's linter if configured (detect from package.json scripts, Makefile, etc.)
2. **Type check** — run type checker if applicable (tsc, mypy, etc.)
3. **Build check** — run the build command if configured
4. **Test check** — run the test suite

Report results:
```
✅ Batch <N> applied — <N> files changed
   Lint:  ✅ passed | ❌ <N> errors
   Types: ✅ passed | ❌ <N> errors
   Build: ✅ passed | ❌ failed
   Tests: ✅ <N>/<N> passed | ❌ <N> failures
```

**4c — Handle failures:**

If validation fails after a batch:
```
⚠️ Batch <N> validation failed.

  [fix]      — attempt to auto-fix the failures (max 2 retries)
  [skip]     — continue to next batch (failures may compound)
  [rollback] — revert this batch and stop
```

- **fix** → Run Codex with the error output to fix issues. Re-validate. Max 2 retries before offering rollback.
- **skip** → Continue (warn that failures may compound)
- **rollback** → Revert the batch changes: `git checkout -- <files_in_batch>`

Save batch results to `$SESSION_DIR/04-batch-<N>.md`.

---

## Phase 5: Verify & Report ✅

**Goal:** Confirm the migration succeeded and produce a summary.

### 5a — Final validation

Run the full validation suite one more time:
```bash
# Run whatever the project uses — detect from package.json, Makefile, etc.
# Example: npm run lint && npm run typecheck && npm run build && npm test
```

### 5b — Diff summary

Run `git diff --stat` to capture all changes made.

### 5c — Synthesis report

You (Claude) produce the final report. Save to `$SESSION_DIR/05-report.md` and display:

```markdown
# ✅ Migration Complete: <MIGRATION_TARGET>

## Summary
<2-3 sentence description of what was migrated>

## Changes Applied

| Batch | Files | Status |
|-------|-------|--------|
| 1 — Safe | <N> | ✅ Applied |
| 2 — Moderate | <N> | ✅ Applied |
| 3 — Breaking | <N> | ✅ Applied / ⏭️ Skipped |

## Dependency Changes
| Package | Before | After |
|---------|--------|-------|
| ... | x.x.x | y.y.y |

## Validation Results
- Lint: ✅ / ❌
- Types: ✅ / ❌
- Build: ✅ / ❌
- Tests: <N>/<N> passing

## Files Changed
<git diff --stat output>

## Manual Steps Required
<Any changes that couldn't be automated:
- Database migrations
- Environment variable updates
- CI/CD configuration
- External service updates>

## Rollback Instructions
To revert all changes:
\`\`\`bash
git checkout -- .
# Or restore from stash:
git stash list  # find the flywheel-migrate-backup entry
git stash pop <stash_ref>
\`\`\`

## Suggested Next Steps
- Run `/fw:test` to verify coverage after the migration
- Run `/fw:harden` to check for new security implications
- Run `/fw:review` before merging
- Commit: `git add -A && git commit -m "migrate: <migration_description>"`

## Session Files
All phase outputs saved to: <SESSION_DIR>
```

---

## Error Handling

- **Phase fails** (dispatch.sh exits non-zero): Show the error, offer to retry or skip the phase
- **Codex not available**: Fall back to Claude for Phases 2 and 4 with a note that automated changes may be less precise
- **Gemini not available**: Skip Phase 1b, note the gap in ecosystem research
- **Build/test failures during migration**: Offer fix → skip → rollback options (never auto-continue)
- **User cancels at any phase**: Save session state and print the session directory path
- **Partial migration (only some batches applied)**: Clearly document which batches were applied and which remain

---

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `FLYWHEEL_MAX_TIMEOUT` | `1800` | Max seconds per agent call (30 min) |
| `FLYWHEEL_CODEX_SANDBOX` | `workspace-write` | Codex sandbox mode |
| `FLYWHEEL_SHOW_THINKING` | `true` | Show Codex reasoning output |
| `FLYWHEEL_PROJECT` | `<git repo name>` | Override project name for session isolation |
| `FLYWHEEL_MIGRATE_DIR` | `~/.flywheel/projects/<project>/migrate` | Where migration session files are saved |
