# Flywheel Agent Team Roles

This directory documents the **team orchestration pattern** used by flywheel commands that support Claude Code Agent Teams. It also serves as the canonical reference for how persona identities map to teammate roles.

---

## Overview

When `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set (and `FLYWHEEL_DISABLE_TEAMS` is not `1`), complex flywheel commands spawn parallel agent teammates instead of running phases sequentially. Each teammate receives a **persona identity** — the content of an `fw-*.md` persona file — as their spawn prompt context.

This gives teammates the same behavioral mandates, tool access guidance, and output format expectations as the installed personas in `~/.claude/agents/`.

---

## Persona → Teammate Mapping

| Persona | Role Name | Used By | Task Type |
|---------|-----------|---------|-----------|
| `fw-researcher` | `researcher` | `fw:implement`, `fw:design`, `fw:migrate` | Research |
| `fw-architect` | `architect` | `fw:implement`, `fw:design` | Planning |
| `fw-security-auditor` | `owasp-scanner`, `dependency-auditor`, `secrets-detector` | `fw:harden` | Scan |
| `fw-code-reviewer` | `quality-reviewer` | `fw:review` | Review |
| `fw-security-auditor` | `security-reviewer` | `fw:review` | Review |
| `fw-test-generator` | `test-reviewer`, `test-writer` | `fw:review`, `fw:implement` | Review/Testing |
| `fw-reflector` | `aspect-analyzer-*` | `fw:reflect` | Analysis |
| `fw-migration-engineer` | `codebase-analyzer` | `fw:migrate` | Analysis |

---

## The Team Pattern

Every command that supports agent teams follows this 3-part structure:

### Part A — Team Configuration Header

Added immediately after the command's opening block:

```markdown
## Team Configuration

> **Mode**: `team` when agent teams enabled; `sequential` fallback
> **Template**: `research-and-plan` (from config/team-templates.yaml)
> **Minimum complexity**: `standard` (skip teams for `light`/`small` scope)
> **Detection**: `scripts/team-detect.sh`

| Role | Persona | Phase(s) | Task |
|------|---------|----------|------|
| researcher | fw-researcher | 1b | Ecosystem research |
| architect | fw-architect | 2 | Technical planning |
```

### Part B — Parallel Phase Map

Declares which phases can run concurrently:

```markdown
### Parallel Phases

| Group | Phases | Teammates | Prerequisite |
|-------|--------|-----------|-------------|
| A | 1a + 1b | lead + researcher | None |
| B | 2 | architect | Group A complete |
```

### Part C — Dual-Path Phase Instructions

Each parallelizable phase has two clearly labeled blocks:

```markdown
### Phase 1b: Ecosystem Research

**[TEAM MODE — researcher teammate]**

Lead instructs the team:
"Spawn a teammate named 'researcher' with the following context:

PERSONA IDENTITY:
<contents of agents/personas/fw-researcher.md>

TASK:
<phase-specific research instructions>

DELIVERABLE:
Save output to: <SESSION_DIR>/01-research-ecosystem.md
Mark your task complete when done."

Lead continues Phase 1a in parallel.
Wait for researcher to complete before proceeding to Phase 2.

**[SEQUENTIAL MODE — fallback when agent teams disabled]**

<existing Task(fw-researcher) or dispatch.sh logic — unchanged>
```

---

## Team Lifecycle

Every command that spawns a team must:

1. **Detect** availability at Step 0: `scripts/team-detect.sh`
2. **Create** the team with a descriptive name matching the session
3. **Spawn** teammates with persona identity in spawn prompt
4. **Assign** tasks via the shared task list
5. **Wait** for completion before synthesizing results
6. **Clean up** the team at command end: `"Clean up the team. Shut down all teammates first."`

---

## Spawn Prompt Template

Use this template when spawning any teammate:

```
Spawn a teammate named '<ROLE_NAME>' with the following context:

PERSONA IDENTITY:
<full contents of agents/personas/fw-<persona>.md>

PROJECT CONTEXT:
- Working directory: <pwd>
- Feature/Task: <description>
- Session directory: <SESSION_DIR>

TASK:
<phase-specific instructions from the command>

DELIVERABLE:
Save your output to: <SESSION_DIR>/<phase-number>-<phase-name>.md
When complete, mark your task as done and notify the lead.
```

---

## Cost Guidance

| Team Size | Token Multiplier | Best For |
|-----------|-----------------|---------|
| 2 teammates | ~2-3x | research-and-plan, parallel migration |
| 3 teammates | ~3-4x | parallel-review, parallel-scan |
| 4 teammates | ~4-5x | full reflect (all 4 aspects) |
| 5 teammates | ~5-6x | maximum allowed by FLYWHEEL_MAX_TEAMMATES |

Only use teams for `standard`/`deep` complexity. For `light`/`small` tasks, sequential execution is faster and cheaper.

---

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | `0` | Enable agent teams (Claude Code setting) |
| `FLYWHEEL_DISABLE_TEAMS` | `0` | Kill switch — disables teams regardless of feature flag |
| `FLYWHEEL_MAX_TEAMMATES` | `5` | Maximum teammates per team (cost control) |
| `FLYWHEEL_TEAM_MODE` | `auto` | Display mode: `auto`, `in-process`, `tmux` |

---

## Troubleshooting

**Teammates not appearing:** Use Shift+Down to cycle through active teammates in in-process mode.

**Task stuck pending:** Check if it has `depends_on` that haven't completed. Tell the lead to nudge the blocking teammate.

**Orphaned teams after interruption:** Run `/fw:cleanup teams` to list and remove stale team configs.

**Too many permission prompts:** Pre-approve operations via `/fw:setup` before spawning teammates.

**Lead implementing instead of delegating:** Tell the lead explicitly: "Wait for your teammates to complete their tasks before proceeding."
