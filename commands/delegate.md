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

> **CRITICAL**: You MUST use `dispatch.sh` to spawn agents. DO NOT call `codex`, `claude`, or `gemini` CLIs directly.

1. **Run the dispatcher** (this is the ONLY way to spawn agents):
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh" "<PROVIDER>" "<TASK>" <CONTEXT_FILES>
   ```
   
   **Examples:**
   - `"${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh" "codex" "implement a login form"`
   - `"${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh" "claude" "review this code" src/auth.ts`

2. **What the user will see** — `dispatch.sh` automatically shows a rich banner and live progress:
   ```
   ╔══════════════════════════════════════════════════════════╗
   ║  🔴 Delegating to CODEX                                  ║
   ╠══════════════════════════════════════════════════════════╣
   ║  Model   : gpt-5.3-codex                                 ║
   ║  Task    : implement a login form with validation...     ║
   ║  Started : 2026-02-18 21:16:03                           ║
   ╚══════════════════════════════════════════════════════════╝

     ◐  Running... [00:01:23]  Ctrl+C to cancel
   ```
   The spinner updates every second with elapsed time. **No fixed timeout** — the agent runs until it finishes naturally (up to `FLYWHEEL_MAX_TIMEOUT`, default 30 min).

3. **Read the result file** after dispatch completes:
   ```bash
   PROJECT_NAME="${FLYWHEEL_PROJECT:-$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")")}"
   cat "$HOME/.flywheel/projects/$PROJECT_NAME/results/latest-<PROVIDER>.md"
   ```

## Step 5: Review & Present

After getting the sub-agent's output:
1. **Review** the output for correctness and completeness
2. **Present** the result to the user with the provider indicator (🔴/🔵/🟡)
3. **Offer follow-up**: "Would you like me to refine this, delegate to another agent, or apply these changes?"

## Error Handling

- If `dispatch.sh` is missing: Error "Dispatcher script not found."
- If the provider is not available: Show what providers ARE available and suggest `/fw:setup`
- If the agent exceeds `FLYWHEEL_MAX_TIMEOUT` (default 1800s / 30 min): Report the timeout and suggest increasing it:
  ```bash
  export FLYWHEEL_MAX_TIMEOUT=3600  # allow up to 1 hour
  ```
  Then offer to retry with a simpler prompt or a different provider.

## Thinking Process (Enabled by Default)

For Codex with reasoning models (o1, o3), the thinking process is **automatically displayed** by default.

**What you'll see:**
- 🧠 **Thinking Process** — The model's full reasoning in a collapsible section
- 💡 **Final Output** — Clearer separation from the thinking
- Better insight into how the model approached the problem

**To disable thinking output:**
If you prefer not to see the thinking process, set:
```bash
export FLYWHEEL_SHOW_THINKING=false
```

**Note:** This works best with o-series models (o1, o3) that have native reasoning capabilities. For other models, the output will be the same regardless of this setting.
