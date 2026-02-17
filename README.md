# Flywheel Plugin

A plugin for Flywheel development tools.

## Installation

To install this plugin in Claude Code:

```bash
# 1. Add this repository as a plugin marketplace
claude plugin marketplace add gmedali/flywheel-plugin

# 2. Install the plugin
claude plugin install fw
```

> **Note**: This requires the repository to be public or for you to have authenticated your GitHub account with Claude Code.

**Alternative (Local Development):**
```bash
claude plugin add ./flywheel-plugin
```

## Publishing

To publish a new version of this plugin:

1.  Go to the **Actions** tab in the GitHub repository.
2.  Select the **Release** workflow from the left sidebar.
3.  Click **Run workflow**.
4.  Select the version bump level (`patch`, `minor`, or `major`) and click **Run workflow**.

The workflow will:
1.  Bump the version in `plugin.json`.
2.  Commit and push the change.
3.  Create and push a new tag.
4.  Create a GitHub Release with auto-generated notes.

## commands

### /fw:hello

Run the hello command to see a friendly greeting.

```
/fw:hello
```
