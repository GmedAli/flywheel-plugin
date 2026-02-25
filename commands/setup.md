---
description: Setup and validate provider integrations
---

# Flywheel Setup

This command validates all AI provider integrations and configures the plugin for use.

## Step 1: Bootstrap Configuration

1.  **Create Global Config Directory**:
    *   Run: `mkdir -p ~/.flywheel/projects`

2.  **Create Current Project Directory**:
    *   Detect project name:
        ```bash
        PROJECT_NAME="${FLYWHEEL_PROJECT:-$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")")}"
        mkdir -p "$HOME/.flywheel/projects/$PROJECT_NAME/results"
        ```
    *   **Message**: "Project directory created: `~/.flywheel/projects/<PROJECT_NAME>/`"

3.  **Grant Claude Code Permissions for Project Directory**:
    *   Run the permissions helper so that `Write`, `Edit`, and `Bash` operations targeting the project directory are auto-approved without user prompts:
        ```bash
        "${CLAUDE_PLUGIN_ROOT}/scripts/grant-permissions.sh" "$PROJECT_NAME"
        ```
    *   The script is **idempotent** — safe to run on every setup. It patches `~/.claude/settings.json`, adding three entries only if they are not already present:
        *   `Write(~/.flywheel/projects/<PROJECT_NAME>/**)` — file-write tool
        *   `Edit(~/.flywheel/projects/<PROJECT_NAME>/**)` — file-edit tool
        *   `Bash(*~/.flywheel/projects/<PROJECT_NAME>*)` — any shell command referencing the directory
    *   Uses `jq` when available; falls back to `python3`; prints manual instructions if neither is found.
    *   **Message**: "Permissions granted for `~/.flywheel/projects/<PROJECT_NAME>/`"

4.  **Initialize Agents Config**:
    *   Check if `~/.flywheel/agents.yaml` exists.
    *   **If NOT exists**:
        *   Copy the default configuration:
            ```bash
            cp "${CLAUDE_PLUGIN_ROOT}/config/agents.yaml" ~/.flywheel/agents.yaml
            ```
        *   **Message**: "Initialized default agent configuration."

5.  **Migrate Legacy Sessions** (if any):
    *   Check if flat session directories exist at `~/.flywheel/` (implement/, debug/, results/, etc.)
    *   If found, inform the user:
        ```
        ⚠️ Legacy session data found at ~/.flywheel/ (pre-project isolation).
           Run /fw:cleanup migrate-legacy to move it under the current project.
        ```

## Step 2: Install Flywheel Personas

> **Personas are native Claude Code sub-agents.** They give each `/fw:` command a specialist identity with curated tool access, model routing, and clear behavioural mandates — replacing ad-hoc prompt strings with persistent, reusable agents.

1.  **Create the Claude agents directory**:
    ```bash
    mkdir -p ~/.claude/agents
    ```

2.  **Run the persona installer**:
    ```bash
    "${CLAUDE_PLUGIN_ROOT}/scripts/install-personas.sh"
    ```
    This copies all Flywheel personas from `agents/personas/` to `~/.claude/agents/`, only overwriting files that are older than the installed version.

3.  **Verify installation**:
    ```bash
    ls ~/.claude/agents/fw-*.md
    ```
    Expected personas:
    ```
    fw-architect.md          — /fw:design, /fw:implement (planning phases)
    fw-researcher.md         — All research phases (external best practices)
    fw-debugger.md           — /fw:debug (root-cause analysis)
    fw-security-auditor.md   — /fw:harden (OWASP scanning + CVE audit)
    fw-code-reviewer.md      — /fw:review (PR code review)
    fw-tdd-specialist.md     — /fw:tdd (Red → Green → Refactor)
    fw-test-generator.md     — /fw:test (coverage gap analysis)
    fw-migration-engineer.md — /fw:migrate (breaking change handling)
    fw-fe-designer.md        — /fw:design (frontend UI & component tasks)
    ```

4.  **If personas need updating** (e.g. after a plugin upgrade):
    ```bash
    "${CLAUDE_PLUGIN_ROOT}/scripts/install-personas.sh" --force
    ```

## Step 3: Detect Providers

1.  **Run provider detection** (force fresh check, ignore cache):
    ```bash
    "${CLAUDE_PLUGIN_ROOT}/scripts/detect-providers.sh" --force
    ```

2.  **Display Results**: Present the detection output to the user.

3.  **Guidance based on results**:
    *   **No providers**: Suggest installing Codex CLI (`npm install -g @openai/codex`) or setting `OPENAI_API_KEY`
    *   **Codex not authenticated**: Suggest `codex login` for OAuth or setting `OPENAI_API_KEY`
    *   **All good**: "Providers ready!"

## Step 4: Verify Configuration

1.  Check that `~/.flywheel/agents.yaml` has at least one agent matching an available provider.
2.  Display available commands:
    *   `/fw:implement` — Full feature workflow (research → plan → build → test)
    *   `/fw:delegate` — Delegate a single task to a sub-agent
    *   `/fw:review` — Multi-agent PR code review
    *   `/fw:debug` — Diagnostic workflow (read-only)
    *   `/fw:tdd` — Test-driven development (Red → Green → Refactor)
    *   `/fw:test` — Proactive test generation and coverage analysis
    *   `/fw:migrate` — Framework/dependency migration with rollback
    *   `/fw:harden` — Security audit (OWASP, CVEs, secrets)
    *   `/fw:fe-design` — Build production-grade frontend interfaces (activates FE-design skill)
    *   `/fw:cleanup` — Manage and clear session caches

> **Skills available**: `FE-design` — activated automatically by `fw-fe-designer` for any frontend UI task. See `skills/FE-design/SKILL.md` for details.
