#!/usr/bin/env bash
# Flywheel Agent Teams Detection
# Detects whether Claude Code Agent Teams are available and enabled.
#
# Usage: team-detect.sh [--quiet]
#
# Exit codes:
#   0 — Agent teams available and enabled
#   1 — Agent teams not available or disabled
#
# Output:
#   JSON status object on stdout (unless --quiet)
#   Human-readable status on stderr (unless --quiet)

set -eo pipefail

QUIET=false
[[ "${1:-}" == "--quiet" ]] && QUIET=true

# ─── Detection Logic ──────────────────────────────────────────────────────────

AVAILABLE=false
REASON=""

# Check flywheel-level kill switch first
if [[ "${FLYWHEEL_DISABLE_TEAMS:-0}" == "1" ]]; then
    AVAILABLE=false
    REASON="FLYWHEEL_DISABLE_TEAMS=1 (kill switch active)"

# Check the Claude Code experimental feature flag
elif [[ "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-0}" == "1" ]]; then
    AVAILABLE=true
    REASON="CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1"

# Check settings.json for the env override
else
    SETTINGS_FILE="${HOME}/.claude/settings.json"
    if [[ -f "$SETTINGS_FILE" ]]; then
        # Look for CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS in the env block
        if command -v jq &>/dev/null; then
            FLAG=$(jq -r '.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS // ""' "$SETTINGS_FILE" 2>/dev/null || echo "")
        else
            # Fallback: grep for the key
            FLAG=$(grep -o '"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"[[:space:]]*:[[:space:]]*"[^"]*"' "$SETTINGS_FILE" 2>/dev/null \
                | grep -o '"[^"]*"$' | tr -d '"' || echo "")
        fi

        if [[ "$FLAG" == "1" ]]; then
            AVAILABLE=true
            REASON="CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 (via settings.json)"
        else
            AVAILABLE=false
            REASON="CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS not set (set to '1' in env or settings.json to enable)"
        fi
    else
        AVAILABLE=false
        REASON="CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS not set"
    fi
fi

# ─── Max teammates cap ─────────────────────────────────────────────────────────

MAX_TEAMMATES="${FLYWHEEL_MAX_TEAMMATES:-5}"

# ─── Output ───────────────────────────────────────────────────────────────────

if [[ "$QUIET" != "true" ]]; then
    # JSON output to stdout (machine-readable)
    cat <<EOF
{
  "available": $AVAILABLE,
  "reason": "$REASON",
  "max_teammates": $MAX_TEAMMATES,
  "team_mode": "${FLYWHEEL_TEAM_MODE:-auto}",
  "kill_switch": "${FLYWHEEL_DISABLE_TEAMS:-0}"
}
EOF

    # Human-readable output to stderr
    if [[ "$AVAILABLE" == "true" ]]; then
        echo "🤝 Agent Teams: ENABLED — parallel phases will use teammates (max: $MAX_TEAMMATES)" >&2
        echo "   Display mode: ${FLYWHEEL_TEAM_MODE:-auto} | Kill switch: ${FLYWHEEL_DISABLE_TEAMS:-0}" >&2
    else
        echo "🤝 Agent Teams: OFF — running sequential workflow" >&2
        echo "   Reason: $REASON" >&2
        echo "   To enable: set CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 in env or run /fw:setup" >&2
    fi
fi

# Exit with appropriate code
if [[ "$AVAILABLE" == "true" ]]; then
    exit 0
else
    exit 1
fi
