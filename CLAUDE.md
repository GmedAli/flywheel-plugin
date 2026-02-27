# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flywheel is a **Claude Code plugin** (`fw` v0.1.0) that transforms Claude into an orchestrator spawning specialized sub-agents (Codex, Claude, Gemini) across structured, multi-phase markdown workflows. This is not a compiled application — it's a declarative system of markdown commands, bash scripts, and persona definitions.

## Architecture

```
User → /fw:<command> → Claude reads commands/<command>.md → executes phases
                        ↓ (for delegation phases)
                        scripts/dispatch.sh <provider> <prompt> [context_files...]
                        ↓
                        Sub-agent CLI (codex | claude | gemini)
                        ↓
                        Results → ~/.flywheel/projects/<project>/<command>/<session>/
```

**Core components:**
- **Commands** (`commands/*.md`): Declarative multi-phase workflows that Claude reads and executes step-by-step. Each has scope detection, user gates, and structured output.
- **Personas** (`agents/personas/fw-*.md`): Behavioral definitions for Claude Code sub-agents. Installed to `~/.claude/agents/` via `install-personas.sh`.
- **Dispatch** (`scripts/dispatch.sh`): The execution engine — spawns sub-agent CLIs, enforces timeouts, saves results with per-project isolation.
- **Config** (`config/agents.yaml`): Agent definitions mapping names to providers, models, and capabilities.

**Provider routing:** Codex for implementation, Claude for reasoning/review, Gemini for ecosystem research. Commands auto-select based on task keywords; users can override with `using <provider>`.

## Key Scripts

```bash
# Core orchestration — called by commands, not directly by users
scripts/dispatch.sh <provider> <prompt> [context_files...]

# Install/update personas to ~/.claude/agents/
scripts/install-personas.sh [--force]

# Check provider CLI availability (1-hour cache)
scripts/detect-providers.sh [--force]

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

## Important Patterns

- `dispatch.sh` always saves output to `~/.flywheel/` even on error, and creates a `latest-<provider>.md` symlink
- Context files passed to dispatch are capped at 50KB each
- Personas use `model: opus` for high-reasoning tasks (architect, security-auditor) and `model: sonnet` for everything else
- Commands reference personas by name (e.g., "activate fw-researcher") — these must be installed via `/fw:setup` first
- The plugin uses `$CLAUDE_PLUGIN_ROOT` to reference its own install path in scripts
