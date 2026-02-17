---
description: Ssetup and validate Codex integration
---

# Flywheel Setup

This command validates the Codex integration and configures the plugin for use.

## Step 1: Run Validation Script

1.  **Execute the Script**:
    *   Run the validation script located in the `scripts` directory:
        ```bash
        ./scripts/check_codex.sh
        ```
    *   **Capture Output**: The script will output "✅ ..." or "❌ ..." messages.

2.  **Display Results**:
    *   Present the output directly to the user.

3.  **Check Status**:
    *   **If Exit Code 0 (Success)**:
        *   Configuration has been saved to `.flywheel/config.json`.
        *   **Message**: "Setup complete! You can now use Codex features."

    *   **If Exit Code 1 (Failure)**:
        *   **Message**: "Setup failed. Please check the errors above."
        *   **Action**: Provide guidance based on the error (install CLI or set API key).

## Step 2: Verify Configuration

1.  **Check Config File**:
    *   Run `cat .flywheel/config.json` to verify the settings were saved correctly.
    *   Display the contents if successful.
