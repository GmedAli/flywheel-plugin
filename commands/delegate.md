---
description: Delegate a task to a specialized agent
---

# Agent Delegation / Orchestration

This command allows Claude to delegate complex tasks to specialized sub-agents defined in `config/agents.yaml`.

## Usage
`/fw:delegate <agent> <task_description>`

## Step 1: Validate Request

1.  **Check Arguments**:
    *   Ensure an agent name is provided.
    *   Ensure a task description/prompt is provided.

2.  **Validate Agent**:
    *   Check if the requested agent exists in `config/agents.yaml`.

## Step 2: Dispatch Task

1.  **Execute Dispatcher**:
    *   Run the dispatch script with the agent and prompt:
        ```bash
        "${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh" "<AGENT>" "<TASK>"
        ```
    *   **Note**: The dispatch script handles the connection to the specific provider (e.g., Codex CLI).

2.  **Display Result**:
    *   Output the result from the sub-agent directly.
