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

# Max timeout: how long we'll wait before force-killing (default 30 min)
# Accepts FLYWHEEL_MAX_TIMEOUT (new) or FLYWHEEL_TIMEOUT (legacy fallback)
MAX_TIMEOUT="${FLYWHEEL_MAX_TIMEOUT:-${FLYWHEEL_TIMEOUT:-1800}}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
TMP_OUTPUT=$(mktemp /tmp/flywheel-output-XXXXXX)

# Cleanup on exit (removes temp file, kills background agent if still running)
AGENT_PID=""
cleanup() {
    if [[ -n "$AGENT_PID" ]] && kill -0 "$AGENT_PID" 2>/dev/null; then
        kill -- -"$AGENT_PID" 2>/dev/null || kill "$AGENT_PID" 2>/dev/null || true
    fi
    rm -f "$TMP_OUTPUT"
}
trap cleanup EXIT INT TERM

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
PROVIDER_UPPER=$(echo "$PROVIDER" | tr '[:lower:]' '[:upper:]')
START_TIME=$(date +%s)
START_DISPLAY=$(date "+%Y-%m-%d %H:%M:%S")

# ─── Waiting Banner ───────────────────────────────────────────────────────────

# Truncate task for display (max 55 chars)
TASK_PREVIEW="${RAW_PROMPT:0:55}"
if [[ ${#RAW_PROMPT} -gt 55 ]]; then
    TASK_PREVIEW="${TASK_PREVIEW}..."
fi

print_banner() {
    local width=58
    local border_top="╔$(printf '═%.0s' $(seq 1 $width))╗"
    local border_bot="╚$(printf '═%.0s' $(seq 1 $width))╝"
    local sep="╠$(printf '═%.0s' $(seq 1 $width))╣"

    echo -e "${BOLD}${CYAN}${border_top}${NC}"
    printf "${BOLD}${CYAN}║${NC}  ${INDICATOR} ${BOLD}Delegating to %-41s${CYAN}${BOLD}║${NC}\n" "${PROVIDER_UPPER}"
    echo -e "${BOLD}${CYAN}${sep}${NC}"
    printf "${BOLD}${CYAN}║${NC}  ${DIM}%-56s${NC}${BOLD}${CYAN}║${NC}\n" "Model   : ${MODEL}"
    printf "${BOLD}${CYAN}║${NC}  ${DIM}%-56s${NC}${BOLD}${CYAN}║${NC}\n" "Task    : ${TASK_PREVIEW}"
    printf "${BOLD}${CYAN}║${NC}  ${DIM}%-56s${NC}${BOLD}${CYAN}║${NC}\n" "Started : ${START_DISPLAY}"
    if [[ ${#CONTEXT_FILES[@]} -gt 0 ]]; then
        printf "${BOLD}${CYAN}║${NC}  ${DIM}%-56s${NC}${BOLD}${CYAN}║${NC}\n" "Context : ${#CONTEXT_FILES[@]} file(s) attached"
    fi
    echo -e "${BOLD}${CYAN}${border_bot}${NC}"
    echo ""
}

# ─── Live Spinner ─────────────────────────────────────────────────────────────

SPINNER_FRAMES=("◐" "◓" "◑" "◒")

format_elapsed() {
    local secs=$1
    printf "%02d:%02d:%02d" $((secs/3600)) $(( (secs%3600)/60 )) $((secs%60))
}

wait_for_agent() {
    local pid=$1
    local frame=0
    local elapsed=0

    while kill -0 "$pid" 2>/dev/null; do
        elapsed=$(( $(date +%s) - START_TIME ))

        # Hard ceiling: kill if we exceed max timeout
        if [[ $elapsed -ge $MAX_TIMEOUT ]]; then
            kill -- -"$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
            echo ""
            echo -e "${RED}✗ ${PROVIDER_UPPER} exceeded max timeout of ${MAX_TIMEOUT}s.${NC}" >&2
            echo -e "${DIM}  Increase limit: export FLYWHEEL_MAX_TIMEOUT=<seconds>${NC}" >&2
            return 124
        fi

        local spinner="${SPINNER_FRAMES[$((frame % 4))]}"
        local time_str
        time_str=$(format_elapsed "$elapsed")

        # Overwrite the current line
        printf "\r  ${YELLOW}${spinner}${NC}  ${DIM}Running... [${time_str}]  Ctrl+C to cancel${NC}   " >&2
        frame=$((frame + 1))
        sleep 1
    done

    # Clear the spinner line
    printf "\r%-60s\r" "" >&2
    return 0
}

# ─── Execute ─────────────────────────────────────────────────────────────────

execute_codex() {
    local sandbox="${FLYWHEEL_CODEX_SANDBOX:-workspace-write}"
    codex exec \
        --model "$MODEL" \
        --sandbox "$sandbox" \
        "$FULL_PROMPT" >"$TMP_OUTPUT" 2>&1
}

execute_claude() {
    claude --print \
        -m "$MODEL" \
        -p "$FULL_PROMPT" >"$TMP_OUTPUT" 2>&1
}

execute_gemini() {
    env NODE_NO_WARNINGS=1 gemini \
        -o text \
        --approval-mode yolo \
        -m "$MODEL" \
        -p "" <<<"$FULL_PROMPT" >"$TMP_OUTPUT" 2>&1
}

# Print the banner
print_banner

# Launch provider in background (new process group so we can kill cleanly)
EXIT_CODE=0
case "$PROVIDER" in
    codex)
        set -m  # enable job control / process groups
        execute_codex &
        AGENT_PID=$!
        ;;
    claude)
        set -m
        execute_claude &
        AGENT_PID=$!
        ;;
    gemini)
        set -m
        execute_gemini &
        AGENT_PID=$!
        ;;
esac

# Wait with live spinner
wait_for_agent "$AGENT_PID" || EXIT_CODE=$?

# Collect exit code from background process (if it finished naturally)
if [[ $EXIT_CODE -eq 0 ]]; then
    wait "$AGENT_PID" 2>/dev/null || EXIT_CODE=$?
fi

OUTPUT=$(cat "$TMP_OUTPUT" 2>/dev/null || true)

# ─── Save Results ────────────────────────────────────────────────────────────

ELAPSED_TOTAL=$(( $(date +%s) - START_TIME ))
ELAPSED_DISPLAY=$(format_elapsed "$ELAPSED_TOTAL")

# Parse output for thinking (if present)
THINKING_CONTENT=""
FINAL_OUTPUT="$OUTPUT"

if [[ "$PROVIDER" == "codex" ]] && [[ "${FLYWHEEL_SHOW_THINKING:-true}" == "true" ]]; then
    if echo "$OUTPUT" | grep -q "<thinking>"; then
        THINKING_CONTENT=$(echo "$OUTPUT" | sed -n '/<thinking>/,/<\/thinking>/p' | sed '1d;$d')
        FINAL_OUTPUT=$(echo "$OUTPUT" | sed '/<thinking>/,/<\/thinking>/d')
    fi
fi

{
    echo "# ${INDICATOR} ${PROVIDER_UPPER} Output"
    echo ""
    echo "> **Task:** ${RAW_PROMPT}"
    echo "> **Model:** ${MODEL}"
    echo "> **Timestamp:** $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "> **Duration:** ${ELAPSED_DISPLAY}"
    echo "> **Exit Code:** ${EXIT_CODE}"
    if [[ "${FLYWHEEL_SHOW_THINKING:-true}" == "true" ]]; then
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
    echo -e "${GREEN}✓ ${INDICATOR} ${PROVIDER_UPPER} completed in ${ELAPSED_DISPLAY}${NC}"
    echo -e "${DIM}  Result saved: ${RESULT_FILE}${NC}"
    echo ""
    echo "$OUTPUT"
elif [[ $EXIT_CODE -eq 124 ]]; then
    echo -e "${RED}✗ ${INDICATOR} ${PROVIDER_UPPER} timed out after ${ELAPSED_DISPLAY} (max: ${MAX_TIMEOUT}s)${NC}" >&2
    echo -e "${DIM}  Partial output saved: ${RESULT_FILE}${NC}" >&2
    echo -e "${DIM}  Tip: export FLYWHEEL_MAX_TIMEOUT=3600 to allow up to 1 hour${NC}" >&2
    exit 124
else
    echo -e "${RED}✗ ${INDICATOR} ${PROVIDER_UPPER} failed (exit code: ${EXIT_CODE}) after ${ELAPSED_DISPLAY}${NC}" >&2
    echo -e "${DIM}  Error output saved: ${RESULT_FILE}${NC}" >&2
    echo ""
    echo "$OUTPUT"
    exit $EXIT_CODE
fi
