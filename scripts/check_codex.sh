#!/bin/bash

# Configuration
CONFIG_DIR="$HOME/.flywheel"
CONFIG_FILE="$CONFIG_DIR/config.json"
mkdir -p "$CONFIG_DIR"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔍 Checking Codex Integration..."

# 1. Check for Codex CLI
if command -v codex &> /dev/null; then
    CLI_PATH=$(which codex)
    LOGIN_STATUS=$(codex login status 2>&1)
    
    if echo "$LOGIN_STATUS" | grep -q "Logged in"; then
        echo -e "${GREEN}✅ Codex CLI detected and authenticated.${NC}"
        # Extract model from config if possible
        MODEL=$(cat ~/.codex/config.toml 2>/dev/null | grep "^model =" | cut -d'"' -f2)
        [ -z "$MODEL" ] && MODEL="unknown"
        
        # Persist success
        echo "{\"provider\": \"codex-cli\", \"status\": \"connected\", \"model\": \"$MODEL\", \"path\": \"$CLI_PATH\"}" > "$CONFIG_FILE"
        echo "Configuration saved to $CONFIG_FILE"
        exit 0
    else
        echo -e "${YELLOW}⚠️ Codex CLI found but not logged in.${NC}"
        echo "Run 'codex login' to authenticate."
    fi
else
    echo -e "${YELLOW}⚠️ Codex CLI not installed.${NC}"
fi

# 2. Check for API Key (Fallback)
if [ -n "$OPENAI_API_KEY" ]; then
    echo "🔑 OPENAI_API_KEY detected. Verifying..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $OPENAI_API_KEY" https://api.openai.com/v1/models)
    
    if [ "$HTTP_CODE" -eq 200 ]; then
        echo -e "${GREEN}✅ API Key is valid.${NC}"
        # Persist success
        echo "{\"provider\": \"openai-api\", \"status\": \"connected\", \"model\": \"gpt-4\", \"key_present\": true}" > "$CONFIG_FILE"
        echo "Configuration saved to $CONFIG_FILE"
        exit 0
    else
        echo -e "${RED}❌ API Key is invalid (HTTP $HTTP_CODE).${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ OPENAI_API_KEY not set.${NC}"
fi

echo -e "\n${RED}❌ Codex setup failed.${NC} Please install the Codex CLI or set OPENAI_API_KEY."
exit 1
