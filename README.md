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

### /fw:review

Review Pull Requests with configurable depth and output options.

```
/fw:review
```

#### Features

- **Interactive Configuration**: The command will ask you for:
  - Review level (low, medium, or critical)
  - Output format (local file, draft review, or direct submission)
  - Whether to include proposed solutions
  - Which PR to review

- **Three Review Levels**:
  - **Low**: Superficial review focusing on code style, obvious errors, and simple code smells. Fast (~30 seconds).
  - **Medium**: Context-aware review focusing on breaking changes, missing features, and API contracts. Analyzes immediate context (~1-2 minutes).
  - **Critical**: In-depth comprehensive review checking design patterns, architecture, best practices, security, performance, and test coverage (~3-5 minutes).

- **Multiple Output Options**:
  - **Local**: Save review as a markdown file in your current directory
  - **Draft**: Submit as a draft review on GitHub (you can review before publishing)
  - **Direct**: Submit the review directly to GitHub

- **Proposed Solutions**: Optionally include code suggestions and fixes for identified issues

#### Prerequisites

- GitHub CLI (`gh`) must be installed and authenticated
- Must be run from within a git repository
- Requires read/write permissions on the target repository (for submitting reviews)

#### Usage Example

```bash
# Navigate to your repository
cd /path/to/your/repo

# Run the review command
/fw:review

# Follow the interactive prompts:
# 1. Select review level: low/medium/critical
# 2. Select output format: local/draft/direct
# 3. Include solutions: yes/no
# 4. Enter PR number or leave blank to see list
```

#### Review Output Structure

The review will be structured with:
- Summary of the PR and overall assessment
- Issues categorized by severity (Critical 🔴, Important 🟡, Minor 🟢)
- Detailed review by file with line-specific feedback
- Positive observations
- Recommendations for improvement
- Review decision (approve/request changes/comment)
