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
PROMPT=$2

if [ -z "$AGENT_NAME" ] || [ -z "$PROMPT" ]; then
    echo -e "${RED}Usage: $0 <agent_name> <prompt>${NC}"
    exit 1
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
    echo "Prompt: $PROMPT"
    echo "---"
    
    # Execute with explicit model
    codex exec --model "$MODEL" "$PROMPT"
else
    echo -e "${RED}Error: Provider logic for '$AGENT_NAME' not implemented yet.${NC}"
    exit 1
fi
