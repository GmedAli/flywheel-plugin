---
description: Delegate a task to a specialized agent
---

# Agent Orchestration Wizard

This command provides an interactive interface for delegating tasks to specialized sub-agents.

## Step 1: Initialization & Agent Selection

1.  **Display Banner**:
    ```text
    🐙 FLYWHEEL ORCHESTRATOR
    ========================
    ```

2.  **Determine Agent**:
    *   **If argument provided**: Use `$1` as agent name.
    *   **If NO argument**:
        *   Extract available agents from `~/.flywheel/agents.yaml`.
        *   Ask user: "Which agent would you like to assign this task to?"
        *   (For now, we can hardcode the options if parsing yaml is hard in markdown, or just prompt for name)
        *   *Option*: "codex (Code Expert)"

3.  **Determine Task**:
    *   **If argument provided**: Use `$2` as task description.
    *   **If NO argument**:
        *   Ask user: "What is the task description?"
        *   (User inputs prompt)

## Step 2: Context Selection

1.  **Ask for Context**:
    *   Ask user: "Would you like to include any files for context? (Enter space-separated paths, or press Enter to skip)"
    *   **User Input**: `files...`

## Step 3: Execution

1.  **Prepare Dispatch**:
    *   Show status: "⚡ Dispatching to [AGENT]..."

2.  **Run Dispatcher**:
    *   Execute the script with all gathered arguments:
        ```bash
        "${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh" "<AGENT>" "<TASK>" <CONTEXT_FILES>
        ```

3.  **Display Output**:
    *   Stream the output from the dispatch script.

## Error Handling

*   If `dispatch.sh` is missing: Error "Dispatcher script not found."
*   If `agents.yaml` is missing: Error "Configuration not found. Run /fw:setup."
