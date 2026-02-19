#!/bin/bash
# Flywheel Persona Installer
# Copies Flywheel Claude Code personas from the plugin to ~/.claude/agents/
# Called by /fw:setup (commands/setup.md) or directly.
#
# Usage: install-personas.sh [--force]
#   --force   Overwrite existing persona files even if they exist

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"
PERSONAS_DIR="${PLUGIN_DIR}/agents/personas"
AGENTS_DIR="${HOME}/.claude/agents"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

FORCE=false
if [[ "${1:-}" == "--force" ]]; then
    FORCE=true
fi

# ─── Validate personas source exists ─────────────────────────────────────────

if [[ ! -d "$PERSONAS_DIR" ]]; then
    echo -e "${RED}✗ Personas directory not found: ${PERSONAS_DIR}${NC}" >&2
    echo -e "${DIM}  Plugin may be missing agents/personas/ directory.${NC}" >&2
    exit 1
fi

PERSONA_FILES=("${PERSONAS_DIR}"/fw-*.md)
if [[ ${#PERSONA_FILES[@]} -eq 0 ]] || [[ ! -f "${PERSONA_FILES[0]}" ]]; then
    echo -e "${RED}✗ No persona files found in: ${PERSONAS_DIR}${NC}" >&2
    exit 1
fi

# ─── Create target directory ──────────────────────────────────────────────────

mkdir -p "$AGENTS_DIR"

# ─── Install personas ─────────────────────────────────────────────────────────

INSTALLED=0
SKIPPED=0
OVERWRITTEN=0
FAILED=0

echo ""
echo -e "${BOLD}${CYAN}Installing Flywheel Personas${NC}"
echo -e "${DIM}Source : ${PERSONAS_DIR}${NC}"
echo -e "${DIM}Target : ${AGENTS_DIR}${NC}"
echo ""

for persona_file in "${PERSONA_FILES[@]}"; do
    persona_name=$(basename "$persona_file")
    target_file="${AGENTS_DIR}/${persona_name}"

    if [[ -f "$target_file" ]] && [[ "$FORCE" == "false" ]]; then
        # Check if the source is newer
        if [[ "$persona_file" -nt "$target_file" ]]; then
            cp "$persona_file" "$target_file"
            echo -e "  ${GREEN}✓${NC} ${persona_name} ${DIM}(updated — newer version available)${NC}"
            ((OVERWRITTEN++))
        else
            echo -e "  ${YELLOW}–${NC} ${persona_name} ${DIM}(skipped — already up to date)${NC}"
            ((SKIPPED++))
        fi
    else
        if cp "$persona_file" "$target_file" 2>/dev/null; then
            if [[ -f "$target_file" ]] && [[ "$FORCE" == "true" ]]; then
                echo -e "  ${GREEN}✓${NC} ${persona_name} ${DIM}(overwritten)${NC}"
                ((OVERWRITTEN++))
            else
                echo -e "  ${GREEN}✓${NC} ${persona_name}"
                ((INSTALLED++))
            fi
        else
            echo -e "  ${RED}✗${NC} ${persona_name} ${RED}(failed to copy)${NC}"
            ((FAILED++))
        fi
    fi
done

echo ""
echo -e "${BOLD}Result:${NC} ${GREEN}${INSTALLED} installed${NC}, ${OVERWRITTEN} updated, ${SKIPPED} skipped, ${RED}${FAILED} failed${NC}"
echo ""

if [[ $FAILED -gt 0 ]]; then
    echo -e "${RED}✗ Some personas failed to install. Check permissions on ${AGENTS_DIR}${NC}" >&2
    exit 1
fi

# ─── Post-install summary ─────────────────────────────────────────────────────

echo -e "${BOLD}Installed Flywheel Personas:${NC}"
echo "───────────────────────────────────────────────────────────"
printf "  %-30s  %-8s  %s\n" "Persona" "Model" "Used by"
echo "───────────────────────────────────────────────────────────"
printf "  %-30s  %-8s  %s\n" "fw-architect"          "opus"   "/fw:design, /fw:implement (planning)"
printf "  %-30s  %-8s  %s\n" "fw-researcher"         "sonnet" "All research phases"
printf "  %-30s  %-8s  %s\n" "fw-debugger"           "sonnet" "/fw:debug"
printf "  %-30s  %-8s  %s\n" "fw-security-auditor"   "opus"   "/fw:harden"
printf "  %-30s  %-8s  %s\n" "fw-code-reviewer"      "sonnet" "/fw:review"
printf "  %-30s  %-8s  %s\n" "fw-tdd-specialist"     "sonnet" "/fw:tdd"
printf "  %-30s  %-8s  %s\n" "fw-test-generator"     "sonnet" "/fw:test"
printf "  %-30s  %-8s  %s\n" "fw-migration-engineer" "sonnet" "/fw:migrate"
echo "───────────────────────────────────────────────────────────"
echo ""
echo -e "${DIM}Tip: Re-run /fw:setup or this script to update personas after plugin upgrades.${NC}"
echo -e "${DIM}     Use --force to overwrite all: ${SCRIPT_DIR}/install-personas.sh --force${NC}"
echo ""
