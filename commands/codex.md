---
description: Check Codex (OpenAI) connection status
---

# Codex Status Check

This command checks the status of the Codex integration by verifying the API key and connectivity to OpenAI.

## Step 1: Check Environment Variable

1.  **Check for `OPENAI_API_KEY`**:
    *   Execute the following command to check if the environment variable is set:
        ```bash
        printenv OPENAI_API_KEY
        ```
    *   **If the output is empty**:
        *   ❌ **Status**: Not Configured
        *   **Action**: Inform the user that `OPENAI_API_KEY` is not set.
        *   **Guidance**: Tell the user to set it using `export OPENAI_API_KEY=sk-...` or add it to their shell profile.
        *   **Stop** here.

    *   **If the output is NOT empty**:
        *   ✅ **Status**: API Key Detected
        *   Proceed to Step 2.

## Step 2: Verify Connectivity

1.  **Test API Connection**:
    *   Run the following `curl` command to list models. This verifies the key is valid and can reach OpenAI.
        ```bash
        curl https://api.openai.com/v1/models \
          -H "Authorization: Bearer $OPENAI_API_KEY" \
          --fail \
          --silent \
          --output /dev/null \
          --write-out "%{http_code}"
        ```
        *(Note: The command is silent and only outputs the HTTP status code)*

2.  **Analyze Result**:
    *   **If Output is `200`**:
        *   ✅ **Codex Integration**: Connected
        *   **Message**: "Successfully connected to OpenAI."
        *   **Extra**: Run `curl -s -H "Authorization: Bearer $OPENAI_API_KEY" https://api.openai.com/v1/models | jq -r '.data[].id' | grep -E 'gpt-4|o1|codex' | head -n 5` to show a few available coding models.

    *   **If Output is `401`**:
        *   ❌ **Codex Integration**: Unauthorized
        *   **Message**: "The API Key was detected but rejected by OpenAI. Please check if it is valid."

    *   **If Output is `429`**:
        *   ⚠️ **Codex Integration**: Rate Limited
        *   **Message**: "You have exceeded your quota or rate limit."

    *   **Any other code**:
        *   ❌ **Codex Integration**: Connection Failed
        *   **Message**: "HTTP Status Code: <CODE>"

## Step 3: Report

Present the findings to the user in a clear, summarized format.

```markdown
### Codex Integration Status

*   **API Key**: <Detected/Missing>
*   **Connectivity**: <Connected/Failed>
*   **Models**: <List a few if connected>

<Additional guidance or error messages>
```
