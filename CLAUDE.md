# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flywheel is a **Claude Code plugin** (`fw` v1.1.0) that transforms Claude into an orchestrator spawning specialized sub-agents (Codex, Claude, Gemini) across structured, multi-phase markdown workflows. This is not a compiled application — it's a declarative system of markdown commands, bash scripts, and persona definitions.

## Architecture

```
User → /fw:<command> → Claude reads commands/<command>.md → executes phases
                        ↓
              ┌─ Detect: AGENT_TEAMS enabled? ─────────────────┐
              │                                                  │
         [YES: Team Mode]                              [NO: Sequential Mode]
         Spawn parallel teammates                      dispatch.sh sequential
         (Claude-to-Claude via agent teams)            (unchanged behavior)
              │                                                  │
              └──────────────── External providers ─────────────┘
                                 scripts/dispatch.sh
                                 (codex | gemini only)
                                        ↓
                        Results → ~/.flywheel/projects/<project>/<command>/<session>/
```

**Core components:**
- **Commands** (`commands/*.md`): Declarative multi-phase workflows with dual-path logic — team mode when enabled, sequential fallback otherwise.
- **Personas** (`agents/personas/fw-*.md`): Behavioral definitions for Claude Code sub-agents. Installed to `~/.claude/agents/` via `install-personas.sh`. Also used as teammate identity context in team mode.
- **Team Templates** (`config/team-templates.yaml`): Reusable team composition templates (research-and-plan, parallel-review, parallel-scan, etc.).
- **Dispatch** (`scripts/dispatch.sh`): The execution engine for external providers — spawns Codex/Gemini CLIs, enforces timeouts, saves results.
- **Team Detection** (`scripts/team-detect.sh`): Checks whether `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is enabled.
- **Config** (`config/agents.yaml`): Agent definitions mapping names to providers, models, and capabilities.

**Provider routing:** Codex for implementation, Gemini for ecosystem research (via dispatch.sh). Claude-to-Claude delegation uses native agent teams (when enabled) or sequential persona invocation.

## Key Scripts

```bash
# Core orchestration — called by commands for external providers (codex, gemini)
scripts/dispatch.sh <provider> <prompt> [context_files...]

# Install/update personas to ~/.claude/agents/
scripts/install-personas.sh [--force]

# Check provider CLI availability (1-hour cache)
scripts/detect-providers.sh [--force]

# Detect whether Claude Code Agent Teams are enabled
scripts/team-detect.sh [--quiet]

# Grant Claude Code bash permissions for a project directory
scripts/grant-permissions.sh
```

## Releasing

Releases are manual via GitHub Actions (`workflow_dispatch`):
1. Go to Actions → Release → Run workflow
2. Select bump level: patch / minor / major
3. Workflow updates `.claude-plugin/plugin.json` version, creates git tag and GitHub release

Version lives in `.claude-plugin/plugin.json`. No npm publish step.

## Conventions

**Naming:**
- Commands: `commands/<name>.md` (lowercase, no dashes)
- Personas: `agents/personas/fw-<role>.md` (kebab-case, `fw-` prefix)
- Scripts: `scripts/<name>.sh` (kebab-case)

**Commit style:** Conventional commits — `feat:`, `fix:`, `refactor:`, `chore:`, `docs:`

**Command structure:** Every command markdown follows a phased pattern:
- Phase 0: Parse input, detect scope (small/medium/large or light/standard/deep)
- Phases 1+: Domain-specific work with persona activations
- User gate: Mandatory approval before expensive operations
- Final phase: Save session to `~/.flywheel/`

**Persona structure:** YAML frontmatter (name, model, tools, when_to_use) + Identity + Approach + Output Format + Non-Negotiables sections.

**Session storage:** `~/.flywheel/projects/<project>/<command>/<timestamp>/` — project name auto-detected from git repo basename or overridden via `FLYWHEEL_PROJECT` env var.

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `FLYWHEEL_MAX_TIMEOUT` | `1800` | Max sub-agent execution time in seconds |
| `FLYWHEEL_CODEX_SANDBOX` | `workspace-write` | Codex sandbox mode |
| `FLYWHEEL_SHOW_THINKING` | `true` | Extract thinking from o-series models |
| `FLYWHEEL_PROJECT` | (git repo name) | Override project name for session isolation |
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | `0` | Enable agent teams feature (Claude Code setting) |
| `FLYWHEEL_DISABLE_TEAMS` | `0` | Kill switch — disables teams even if feature flag is on |
| `FLYWHEEL_MAX_TEAMMATES` | `5` | Maximum teammates per team (cost control) |
| `FLYWHEEL_TEAM_MODE` | `auto` | Team display mode: `auto`, `in-process`, `tmux` |

## Agent Teams Integration

Commands that support parallel teammate execution when `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`:

| Command | Team Template | Parallel Phases | Teammates |
|---------|--------------|-----------------|-----------|
| `/fw:implement` | `research-and-plan` | 1a+1b, 7+8 | researcher, architect, test-writer |
| `/fw:design` | `research-and-plan` | 1+2 | researcher, architect |
| `/fw:review` | `parallel-review` | All analysis (critical level) | security, quality, test reviewers |
| `/fw:reflect` | `parallel-analysis` | Phase 2 aspects | 1 per aspect (up to 4) |
| `/fw:harden` | `parallel-scan` | Phase 1 scans | owasp, dependency, secrets scanners |
| `/fw:migrate` | `parallel-migration-research` | Phase 1b | framework-researcher, codebase-analyzer |

**Enabling:** Run `/fw:setup` and select "yes" for agent teams, or set `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` manually.

**Fallback:** All commands work identically without the feature flag — sequential mode is the default.

**Team cleanup:** Every team-enabled command cleans up its team at the end. For orphaned teams: `/fw:cleanup teams`.

**Token cost:** Each teammate is a separate Claude instance. Teams cost ~2-4x more tokens than sequential mode. Use `FLYWHEEL_DISABLE_TEAMS=1` to temporarily disable without removing the feature flag.

**Pattern documentation:** See `agents/team-roles/README.md` for the full team orchestration pattern used by commands.

## Important Patterns

- `dispatch.sh` always saves output to `~/.flywheel/` even on error, and creates a `latest-<provider>.md` symlink
- Context files passed to dispatch are capped at 50KB each
- Personas use `model: opus` for high-reasoning tasks (architect, security-auditor) and `model: sonnet` for everything else
- Commands reference personas by name (e.g., "activate fw-researcher") — these must be installed via `/fw:setup` first
- In team mode, persona identity is injected directly into teammate spawn prompts — personas do not need to be installed for team mode to work
- The plugin uses `$CLAUDE_PLUGIN_ROOT` to reference its own install path in scripts
- Team detection: `scripts/team-detect.sh` exits 0 if available, 1 if not — designed for use in conditional logic within commands
