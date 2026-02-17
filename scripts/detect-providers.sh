#!/bin/bash
# Flywheel Provider Detection
# Detects available AI providers (Codex, Claude, Gemini) and caches results.
# Usage: detect-providers.sh [--force]

set -eo pipefail

# Configuration
FLYWHEEL_DIR="$HOME/.flywheel"
CACHE_FILE="$FLYWHEEL_DIR/.provider-cache"
CACHE_TTL=3600  # 1 hour

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
DIM='\033[2m'
NC='\033[0m'

mkdir -p "$FLYWHEEL_DIR"

# ─── Cache Check ──────────────────────────────────────────────────────────────

use_cache() {
    if [[ "$1" == "--force" ]]; then
        return 1
    fi

    if [[ -f "$CACHE_FILE" ]]; then
        local cache_age
        local now=$(date +%s)
        local cached_at=$(head -1 "$CACHE_FILE" 2>/dev/null | grep -oE '[0-9]+' || echo "0")
        cache_age=$((now - cached_at))

        if [[ $cache_age -lt $CACHE_TTL ]]; then
            # Cache is fresh, output cached results (skip timestamp line)
            tail -n +2 "$CACHE_FILE"
            return 0
        fi
    fi
    return 1
}

# Try cache first
if use_cache "$1"; then
    exit 0
fi

# ─── Provider Detection ──────────────────────────────────────────────────────

CODEX_STATUS="missing"
CODEX_AUTH="none"
CODEX_MODEL=""

CLAUDE_STATUS="missing"
CLAUDE_AUTH="none"
CLAUDE_VERSION=""

GEMINI_STATUS="missing"
GEMINI_AUTH="none"

# --- Codex CLI ---
if command -v codex &>/dev/null; then
    CODEX_STATUS="installed"

    # Check OAuth login
    login_output=$(codex login status 2>&1 || true)
    if echo "$login_output" | grep -qi "logged in"; then
        CODEX_AUTH="oauth"
        CODEX_STATUS="ok"
    elif [[ -n "${OPENAI_API_KEY:-}" ]]; then
        CODEX_AUTH="api-key"
        CODEX_STATUS="ok"
    fi

    # Try to get configured model
    if [[ -f "$HOME/.codex/config.toml" ]]; then
        CODEX_MODEL=$(grep "^model =" "$HOME/.codex/config.toml" 2>/dev/null | cut -d'"' -f2 || echo "")
    fi
    [[ -z "$CODEX_MODEL" ]] && CODEX_MODEL="gpt-5.3-codex"
elif [[ -n "${OPENAI_API_KEY:-}" ]]; then
    CODEX_STATUS="api-only"
    CODEX_AUTH="api-key"
fi

# --- Claude CLI ---
if command -v claude &>/dev/null; then
    CLAUDE_STATUS="ok"
    CLAUDE_AUTH="built-in"
    CLAUDE_VERSION=$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
fi

# --- Gemini CLI ---
if command -v gemini &>/dev/null; then
    GEMINI_STATUS="installed"

    if [[ -n "${GEMINI_API_KEY:-}" ]] || [[ -n "${GOOGLE_API_KEY:-}" ]]; then
        GEMINI_AUTH="api-key"
        GEMINI_STATUS="ok"
    else
        # Check if OAuth is configured (gemini stores tokens internally)
        GEMINI_AUTH="possible-oauth"
        GEMINI_STATUS="ok"
    fi
elif [[ -n "${GEMINI_API_KEY:-}" ]] || [[ -n "${GOOGLE_API_KEY:-}" ]]; then
    GEMINI_STATUS="api-only"
    GEMINI_AUTH="api-key"
fi

# ─── Output Results ──────────────────────────────────────────────────────────

output_results() {
    echo "CODEX_STATUS=$CODEX_STATUS"
    echo "CODEX_AUTH=$CODEX_AUTH"
    echo "CODEX_MODEL=$CODEX_MODEL"
    echo ""
    echo "CLAUDE_STATUS=$CLAUDE_STATUS"
    echo "CLAUDE_AUTH=$CLAUDE_AUTH"
    echo "CLAUDE_VERSION=$CLAUDE_VERSION"
    echo ""
    echo "GEMINI_STATUS=$GEMINI_STATUS"
    echo "GEMINI_AUTH=$GEMINI_AUTH"
}

# Pretty-print summary
echo ""
echo -e "${BLUE}🔍 Flywheel Provider Detection${NC}"
echo "─────────────────────────────────"

# Codex
if [[ "$CODEX_STATUS" == "ok" ]]; then
    echo -e "  🔴 Codex CLI:  ${GREEN}✓ Available${NC} ${DIM}(auth: $CODEX_AUTH, model: $CODEX_MODEL)${NC}"
elif [[ "$CODEX_STATUS" == "installed" ]]; then
    echo -e "  🔴 Codex CLI:  ${YELLOW}⚠ Installed but not authenticated${NC}"
elif [[ "$CODEX_STATUS" == "api-only" ]]; then
    echo -e "  🔴 Codex CLI:  ${YELLOW}⚠ API key found but CLI not installed${NC}"
else
    echo -e "  🔴 Codex CLI:  ${RED}✗ Not available${NC}"
fi

# Claude
if [[ "$CLAUDE_STATUS" == "ok" ]]; then
    echo -e "  🔵 Claude CLI: ${GREEN}✓ Available${NC} ${DIM}(v$CLAUDE_VERSION)${NC}"
else
    echo -e "  🔵 Claude CLI: ${RED}✗ Not available${NC}"
fi

# Gemini
if [[ "$GEMINI_STATUS" == "ok" ]]; then
    echo -e "  🟡 Gemini CLI: ${GREEN}✓ Available${NC} ${DIM}(auth: $GEMINI_AUTH)${NC}"
elif [[ "$GEMINI_STATUS" == "installed" ]]; then
    echo -e "  🟡 Gemini CLI: ${YELLOW}⚠ Installed but not authenticated${NC}"
else
    echo -e "  🟡 Gemini CLI: ${DIM}✗ Not available${NC}"
fi

echo "─────────────────────────────────"

# Count available providers
available=0
[[ "$CODEX_STATUS" == "ok" ]] && available=$((available + 1))
[[ "$CLAUDE_STATUS" == "ok" ]] && available=$((available + 1))
[[ "$GEMINI_STATUS" == "ok" ]] && available=$((available + 1))

if [[ $available -eq 0 ]]; then
    echo -e "  ${RED}No providers available. Run /fw:setup${NC}"
    echo ""
elif [[ $available -eq 1 ]]; then
    echo -e "  ${GREEN}1 provider ready${NC}"
    echo ""
else
    echo -e "  ${GREEN}${available} providers ready${NC}"
    echo ""
fi

# ─── Write Cache ──────────────────────────────────────────────────────────────

{
    echo "CACHED_AT=$(date +%s)"
    output_results
} > "$CACHE_FILE"

# Also output machine-readable results
output_results
