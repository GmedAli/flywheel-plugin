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

3.  **Initialize Agents Config**:
    *   Check if `~/.flywheel/agents.yaml` exists.
    *   **If NOT exists**:
        *   Copy the default configuration:
            ```bash
            cp "${CLAUDE_PLUGIN_ROOT}/config/agents.yaml" ~/.flywheel/agents.yaml
            ```
        *   **Message**: "Initialized default agent configuration."

4.  **Migrate Legacy Sessions** (if any):
    *   Check if flat session directories exist at `~/.flywheel/` (implement/, debug/, results/, etc.)
    *   If found, inform the user:
        ```
        ⚠️ Legacy session data found at ~/.flywheel/ (pre-project isolation).
           Run /fw:cleanup migrate-legacy to move it under the current project.
        ```

## Step 2: Detect Providers

1.  **Run provider detection** (force fresh check, ignore cache):
    ```bash
    "${CLAUDE_PLUGIN_ROOT}/scripts/detect-providers.sh" --force
    ```

2.  **Display Results**: Present the detection output to the user.

3.  **Guidance based on results**:
    *   **No providers**: Suggest installing Codex CLI (`npm install -g @openai/codex`) or setting `OPENAI_API_KEY`
    *   **Codex not authenticated**: Suggest `codex login` for OAuth or setting `OPENAI_API_KEY`
    *   **All good**: "Setup complete! You can now use `/fw:delegate` to dispatch tasks."

## Step 3: Verify Configuration

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
    *   `/fw:cleanup` — Manage and clear session caches
