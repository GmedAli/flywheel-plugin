---
description: Setup and validate provider integrations
---

# Flywheel Setup

This command validates all AI provider integrations and configures the plugin for use.

## Step 1: Bootstrap Configuration

1.  **Create Global Config Directory**:
    *   Run: `mkdir -p ~/.flywheel`

2.  **Initialize Agents Config**:
    *   Check if `~/.flywheel/agents.yaml` exists.
    *   **If NOT exists**:
        *   Copy the default configuration:
            ```bash
            cp "${CLAUDE_PLUGIN_ROOT}/config/agents.yaml" ~/.flywheel/agents.yaml
            ```
        *   **Message**: "Initialized default agent configuration."

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
    *   `/fw:delegate` — Delegate tasks to sub-agents
    *   `/fw:review` — Code review with sub-agent analysis
