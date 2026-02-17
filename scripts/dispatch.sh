#!/bin/bash

# Configuration
# Configuration
CONFIG_FILE="$HOME/.flywheel/config.json"
AGENTS_FILE="$HOME/.flywheel/agents.yaml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

AGENT_NAME=$1
RAW_PROMPT=$2
shift 2
CONTEXT_FILES=("$@")

if [ -z "$AGENT_NAME" ] || [ -z "$RAW_PROMPT" ]; then
    echo -e "${RED}Usage: $0 <agent_name> <prompt> [context_files...]${NC}"
    exit 1
fi

# Construct Full Prompt with Context
FULL_PROMPT="$RAW_PROMPT"

if [ ${#CONTEXT_FILES[@]} -gt 0 ]; then
    FULL_PROMPT+=$'\n\n=== CONTEXT FILES ===\n'
    for file in "${CONTEXT_FILES[@]}"; do
        if [ -f "$file" ]; then
            FULL_PROMPT+="--- File: $file ---\n"
            FULL_PROMPT+="$(cat "$file")\n"
            FULL_PROMPT+="--- End of $file ---\n\n"
        else
            echo -e "${RED}Warning: Context file '$file' not found, skipping.${NC}" >&2
        fi
    done
fi

# 1. Validate Environment
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Error: Flywheel not configured. Run /fw:setup first.${NC}"
    exit 1
fi

# 2. Lookup Agent (Simple grep for now, ideally use yq/jq)
# This is a basic implementation; more robust parsing would be needed for complex yml
if ! grep -q "name: \"$AGENT_NAME\"" "$AGENTS_FILE"; then
    echo -e "${RED}Error: Agent '$AGENT_NAME' not found in $AGENTS_FILE.${NC}"
    exit 1
fi

# 3. Get Provider Command
# Assuming codex for now as the primary agent
if [ "$AGENT_NAME" == "codex" ]; then
    # Extract config from agents.yaml (Simple parser)
    MODEL=$(grep -A 10 "name: \"codex\"" "$AGENTS_FILE" | grep "model:" | cut -d'"' -f2)
    # Default fallback if extraction fails
    [ -z "$MODEL" ] && MODEL="gpt-5.3-codex"
    
    echo -e "${GREEN}🤖 Delegating to Codex ($MODEL)...${NC}"
    echo "Prompt: $RAW_PROMPT"
    if [ ${#CONTEXT_FILES[@]} -gt 0 ]; then
        echo -e "${GREEN}Attached ${#CONTEXT_FILES[@]} context files.${NC}"
    fi
    echo "---"
    
    # Execute with explicit model
    codex exec --model "$MODEL" "$FULL_PROMPT"
else
    echo -e "${RED}Error: Provider logic for '$AGENT_NAME' not implemented yet.${NC}"
    exit 1
fi
