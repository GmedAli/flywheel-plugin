---
description: Check Codex (OpenAI) connection status
---

# Codex Status Check

This command checks the status of the Codex integration by verifying the Codex CLI or API key connectivity.

## Step 1: Method A - Check Codex CLI (Preferred)

1.  **Check for CLI**:
    *   Run `which codex` (or `where codex` on Windows) to see if the CLI is installed.
    *   **If output is NOT empty**:
        *   Proceed to check login status.
        *   Run a simple CLI command like `codex model list` (or equivalent status command).
        *   **If successful (Exit Code 0)**:
            *   ✅ **Status**: CLI Authenticated
            *   **Message**: "Using authenticated Codex CLI."
            *   **Action**: List a few available models using the CLI output.
            *   **Stop** here.
        *   **If failed**:
            *   ⚠️ **Status**: CLI Installed but Not Logged In
            *   **Action**: Proceed to **Method B** (Fallback).

    *   **If output is empty**:
        *   Proceed to **Method B**.

## Step 2: Method B - Check API Key (Fallback)

1.  **Check for `OPENAI_API_KEY`**:
    *   Execute: `printenv OPENAI_API_KEY`
    *   **If output is NOT empty**:
        *   ✅ **Status**: API Key Detected
        *   Proceed to verify connectivity via `curl`.

    *   **If output is empty**:
        *   ❌ **Status**: Not Configured
        *   **Message**: "Neither Codex CLI nor OPENAI_API_KEY found."
        *   **Guidance**:
            *   **Option 1**: Log in to Codex CLI: `codex login`
            *   **Option 2**: Set environment variable: `export OPENAI_API_KEY=sk-...`
        *   **Stop** here.

2.  **Verify API Connectivity**:
    *   Run:
        ```bash
        curl https://api.openai.com/v1/models \
          -H "Authorization: Bearer $OPENAI_API_KEY" \
          --fail \
          --silent \
          --output /dev/null \
          --write-out "%{http_code}"
        ```
    *   **Analyze Result**:
        *   `200`: ✅ **Connected**. Run: `curl -s -H "Authorization: Bearer $OPENAI_API_KEY" https://api.openai.com/v1/models | jq -r '.data[].id' | grep -E 'gpt-4|o1|codex' | head -n 5`
        *   `401`: ❌ **Unauthorized** (Invalid Key).
        *   `429`: ⚠️ **Rate Limited**.
        *   Other: ❌ **Connection Failed**.

## Step 3: Report

Summarize the findings:

```markdown
### Codex Integration Status

*   **Auth Method**: <CLI / API Key / None>
*   **Connectivity**: <Connected / Failed>
*   **Models**: <List of models found>
```
