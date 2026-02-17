#!/bin/bash
# Flywheel Multi-Provider Dispatch
# Spawns sub-agents (Codex, Claude, Gemini) and captures their output.
# Called by Claude (the orchestrator) from command markdown files.
#
# Usage: dispatch.sh <provider> <prompt> [context_files...]
#   provider: codex | claude | gemini
#   prompt:   the task description for the sub-agent
#   context_files: optional files to include as context

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"

# Configuration
FLYWHEEL_DIR="$HOME/.flywheel"
AGENTS_FILE="$FLYWHEEL_DIR/agents.yaml"
RESULTS_DIR="$FLYWHEEL_DIR/results"
TIMEOUT="${FLYWHEEL_TIMEOUT:-300}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Arguments ────────────────────────────────────────────────────────────────

PROVIDER="$1"
RAW_PROMPT="$2"

if [[ -z "$PROVIDER" ]] || [[ -z "$RAW_PROMPT" ]]; then
    echo -e "${RED}Usage: dispatch.sh <provider> <prompt> [context_files...]${NC}"
    echo ""
    echo "  Providers: codex, claude, gemini"
    echo ""
    echo "  Examples:"
    echo "    dispatch.sh codex \"Implement a login form\""
    echo "    dispatch.sh claude \"Review this code\" src/auth.ts"
    echo "    dispatch.sh gemini \"Research OAuth patterns\""
    exit 1
fi

shift 2
CONTEXT_FILES=("$@")

# ─── Setup ────────────────────────────────────────────────────────────────────

mkdir -p "$RESULTS_DIR"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
RESULT_FILE="$RESULTS_DIR/${TIMESTAMP}-${PROVIDER}.md"

# ─── Construct Prompt with Context ────────────────────────────────────────────

FULL_PROMPT="$RAW_PROMPT"

if [[ ${#CONTEXT_FILES[@]} -gt 0 ]]; then
    FULL_PROMPT+=$'\n\n=== CONTEXT FILES ===\n'
    for file in "${CONTEXT_FILES[@]}"; do
        if [[ -f "$file" ]]; then
            # Basic truncation: max 50KB per file
            local_content=$(head -c 51200 "$file")
            FULL_PROMPT+="--- File: $file ---"$'\n'
            FULL_PROMPT+="$local_content"$'\n'
            FULL_PROMPT+="--- End of $file ---"$'\n\n'
        else
            echo -e "${YELLOW}⚠ Context file '$file' not found, skipping.${NC}" >&2
        fi
    done
fi

# ─── Provider Detection ──────────────────────────────────────────────────────

check_provider() {
    local provider="$1"
    case "$provider" in
        codex)
            if ! command -v codex &>/dev/null; then
                echo -e "${RED}✗ Codex CLI not installed.${NC}" >&2
                echo -e "${DIM}  Install: npm install -g @openai/codex${NC}" >&2
                return 1
            fi
            ;;
        claude)
            if ! command -v claude &>/dev/null; then
                echo -e "${RED}✗ Claude CLI not installed.${NC}" >&2
                echo -e "${DIM}  Claude CLI comes with Claude Code.${NC}" >&2
                return 1
            fi
            ;;
        gemini)
            if ! command -v gemini &>/dev/null; then
                echo -e "${RED}✗ Gemini CLI not installed.${NC}" >&2
                echo -e "${DIM}  Install: npm install -g @google/gemini-cli${NC}" >&2
                return 1
            fi
            ;;
        *)
            echo -e "${RED}✗ Unknown provider: '$provider'${NC}" >&2
            echo -e "${DIM}  Available: codex, claude, gemini${NC}" >&2
            return 1
            ;;
    esac
    return 0
}

# Validate provider is available
if ! check_provider "$PROVIDER"; then
    exit 1
fi

# ─── Get Model from Config ───────────────────────────────────────────────────

get_model() {
    local provider="$1"
    local model=""

    # Try to read from agents.yaml if it exists
    if [[ -f "$AGENTS_FILE" ]]; then
        # Find the agent block matching this provider and extract model
        model=$(awk -v prov="$provider" '
            /^  - name:/ { name="" }
            /provider:.*"'$provider'"/ || /provider: '$provider'/ { found=1 }
            found && /model:/ { gsub(/.*model: *"?/, ""); gsub(/".*/, ""); print; exit }
        ' "$AGENTS_FILE" 2>/dev/null || echo "")
    fi

    # Defaults
    if [[ -z "$model" ]]; then
        case "$provider" in
            codex)  model="gpt-5.3-codex" ;;
            claude) model="sonnet" ;;
            gemini) model="gemini-3-pro-preview" ;;
        esac
    fi

    echo "$model"
}

MODEL=$(get_model "$PROVIDER")

# ─── Provider Indicators ─────────────────────────────────────────────────────

provider_indicator() {
    case "$1" in
        codex)  echo "🔴" ;;
        claude) echo "🔵" ;;
        gemini) echo "🟡" ;;
        *)      echo "⚪" ;;
    esac
}

INDICATOR=$(provider_indicator "$PROVIDER")

# ─── Execute ─────────────────────────────────────────────────────────────────

echo -e "${BOLD}${INDICATOR} Dispatching to ${PROVIDER}${NC} ${DIM}(model: ${MODEL})${NC}"
echo -e "${DIM}Task: ${RAW_PROMPT:0:100}...${NC}"
if [[ ${#CONTEXT_FILES[@]} -gt 0 ]]; then
    echo -e "${DIM}Context: ${#CONTEXT_FILES[@]} file(s) attached${NC}"
fi
echo ""

execute_codex() {
    local sandbox="${FLYWHEEL_CODEX_SANDBOX:-workspace-write}"
    local extra_flags=()
    
    # Enable extended thinking if requested (works with o-series models like o1, o3)
    if [[ "${FLYWHEEL_SHOW_THINKING:-false}" == "true" ]]; then
        extra_flags+=(--enable extended_thinking)
    fi
    
    timeout "$TIMEOUT" codex exec \
        --model "$MODEL" \
        --sandbox "$sandbox" \
        "${extra_flags[@]}" \
        "$FULL_PROMPT" 2>&1
}

execute_claude() {
    timeout "$TIMEOUT" claude --print \
        -m "$MODEL" \
        -p "$FULL_PROMPT" 2>&1
}

execute_gemini() {
    timeout "$TIMEOUT" env NODE_NO_WARNINGS=1 gemini \
        -o text \
        --approval-mode yolo \
        -m "$MODEL" \
        -p "" <<< "$FULL_PROMPT" 2>&1
}

# Run the provider and capture output
EXIT_CODE=0
case "$PROVIDER" in
    codex)
        OUTPUT=$(execute_codex) || EXIT_CODE=$?
        ;;
    claude)
        OUTPUT=$(execute_claude) || EXIT_CODE=$?
        ;;
    gemini)
        OUTPUT=$(execute_gemini) || EXIT_CODE=$?
        ;;
esac

# ─── Save Results ────────────────────────────────────────────────────────────

# Parse output for thinking (if present)
# Codex with extended_thinking typically outputs <thinking>...</thinking> tags
THINKING_CONTENT=""
FINAL_OUTPUT="$OUTPUT"

if [[ "$PROVIDER" == "codex" ]] && [[ "${FLYWHEEL_SHOW_THINKING:-false}" == "true" ]]; then
    # Try to extract thinking tags if present
    if echo "$OUTPUT" | grep -q "<thinking>"; then
        THINKING_CONTENT=$(echo "$OUTPUT" | sed -n '/<thinking>/,/<\/thinking>/p' | sed '1d;$d')
        FINAL_OUTPUT=$(echo "$OUTPUT" | sed '/<thinking>/,/<\/thinking>/d')
    fi
fi

{
    echo "# ${INDICATOR} ${PROVIDER^} Output"
    echo ""
    echo "> **Task:** ${RAW_PROMPT}"
    echo "> **Model:** ${MODEL}"
    echo "> **Timestamp:** $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "> **Exit Code:** ${EXIT_CODE}"
    if [[ "${FLYWHEEL_SHOW_THINKING:-false}" == "true" ]]; then
        echo "> **Thinking:** Enabled"
    fi
    echo ""
    echo "---"
    echo ""
    
    # Display thinking process if available
    if [[ -n "$THINKING_CONTENT" ]]; then
        echo "## 🧠 Thinking Process"
        echo ""
        echo "<details>"
        echo "<summary>Click to expand reasoning</summary>"
        echo ""
        echo '```'
        echo "$THINKING_CONTENT"
        echo '```'
        echo ""
        echo "</details>"
        echo ""
        echo "---"
        echo ""
        echo "## 💡 Final Output"
        echo ""
    fi
    
    echo "$FINAL_OUTPUT"
} > "$RESULT_FILE"

# Also create a "latest" symlink for easy access
ln -sf "$RESULT_FILE" "$RESULTS_DIR/latest-${PROVIDER}.md"

# ─── Output ──────────────────────────────────────────────────────────────────

if [[ $EXIT_CODE -eq 0 ]]; then
    echo -e "${GREEN}${INDICATOR} ${PROVIDER^} completed successfully${NC}"
    echo -e "${DIM}Result saved: ${RESULT_FILE}${NC}"
    echo ""
    echo "$OUTPUT"
elif [[ $EXIT_CODE -eq 124 ]]; then
    echo -e "${RED}${INDICATOR} ${PROVIDER^} timed out after ${TIMEOUT}s${NC}" >&2
    echo -e "${DIM}Partial output saved: ${RESULT_FILE}${NC}" >&2
    exit 124
else
    echo -e "${RED}${INDICATOR} ${PROVIDER^} failed (exit code: ${EXIT_CODE})${NC}" >&2
    echo -e "${DIM}Error output saved: ${RESULT_FILE}${NC}" >&2
    echo ""
    echo "$OUTPUT"
    exit $EXIT_CODE
fi
