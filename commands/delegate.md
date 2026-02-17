---
description: Delegate a task to a sub-agent (Codex, Claude, Gemini)
---

# Delegate Task to Sub-Agent

This command delegates a task to a specialized sub-agent. Claude (you) acts as the orchestrator: you spawn the agent, collect its output, review it, and present the result.

## Step 1: Parse the User's Request

Parse the user's input for:
- **Agent specification**: Look for "using codex", "using claude", "using gemini" in the prompt
- **Task description**: Everything else is the task

**Examples:**
- `/fw:delegate using codex implement a login form` → provider=codex, task="implement a login form"
- `/fw:delegate review this file for bugs` → provider=auto-detect, task="review this file for bugs"

## Step 2: Auto-Detect Provider (if not specified)

If the user didn't specify a provider, choose based on the task type:

| Task Pattern | Best Provider | Why |
|-------------|---------------|-----|
| implement, build, write code, refactor | `codex` | Code generation strength |
| review, analyze, plan, explain | `claude` | Analysis and reasoning |
| research, compare, explore | `gemini` | Broad knowledge, long context |

**Fallback**: If unsure, check which providers are available:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/detect-providers.sh"
```
Use the first available provider in order: codex → claude → gemini.

## Step 3: Ask for Task Description (if missing)

If the user only typed `/fw:delegate` with no arguments:
- Ask: "What task would you like to delegate? You can optionally specify a provider (e.g., 'using codex implement feature X')"

## Step 4: Dispatch to Sub-Agent

1. **Show dispatch banner**:
   ```
   ⚡ Delegating to <PROVIDER>...
   ```

2. **Run the dispatcher**:
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh" "<PROVIDER>" "<TASK>" <CONTEXT_FILES>
   ```

3. **Read the result file** after dispatch completes:
   ```bash
   cat ~/.flywheel/results/latest-<PROVIDER>.md
   ```

## Step 5: Review & Present

After getting the sub-agent's output:
1. **Review** the output for correctness and completeness
2. **Present** the result to the user with the provider indicator (🔴/🔵/🟡)
3. **Offer follow-up**: "Would you like me to refine this, delegate to another agent, or apply these changes?"

## Error Handling

- If `dispatch.sh` is missing: Error "Dispatcher script not found."
- If the provider is not available: Show what providers ARE available and suggest `/fw:setup`
- If the agent times out: Report the timeout and offer to retry with a simpler prompt
