---
description: Review PRs with configurable depth and output options
---

# PR Review Command

> **Persona active:** `fw-code-reviewer` — principal engineer reviewer. Classifies findings by severity (`critical`, `major`, `minor`). Every finding is posted as an **inline comment on the exact line of code** with the issue, impact, and fix.

This command reviews Pull Requests and posts findings as inline draft comments on the specific lines of code — not as one bundled comment.

## Step 1: Ask User for Configuration

Before we begin the review, I need to ask you a few questions to configure the review process:

**Question 1: What review level would you like?**
- `low` - Superficial review, focusing on code style, obvious errors, and simple code smells. No external context needed. Fast (~30 seconds).
- `medium` - Context-aware review focusing on breaking changes, missing features, and API contracts. Analyzes immediate context files. Token-efficient (~1-2 minutes).
- `critical` - In-depth comprehensive review checking design patterns, architecture, best practices, security, performance, and test coverage. Full codebase analysis (~3-5 minutes).

**Question 2: How would you like to receive the review?**
- `local` - Save the review as a markdown file in the current directory
- `draft` - Post inline comments as a **pending** GitHub review (you can review and edit before publishing)
- `direct` - Post inline comments and submit the review immediately to GitHub

**Question 3 (Optional): Which PR would you like to review?**
- Leave blank to see a list of available PRs, or
- Provide a PR number directly (e.g., `123`)

After gathering this information, proceed to Step 2.

---

## Step 2: Verify GitHub CLI and Repository

Before proceeding, verify:

1. Check if we're in a git repository by running: `git rev-parse --is-inside-work-tree`
2. Check if GitHub CLI is installed and authenticated by running: `gh auth status`

If either check fails, inform the user and provide guidance on how to fix it.

---

## Step 3: Fetch PR Information

Based on the user's PR selection:

### If no PR number was provided:
1. Run `gh pr list --json number,title,author,updatedAt,state` to get the list of PRs
2. Display the PRs in a readable format
3. Ask the user which PR number they'd like to review
4. Store the selected PR number

### If PR number was provided:
1. Verify the PR exists by running: `gh pr view <PR_NUMBER> --json number,title`
2. If it doesn't exist, inform the user and ask for a valid PR number

Once you have a valid PR number, proceed to Step 4.

---

## Step 4: Gather PR Context

Fetch the PR details and diff:

1. Get comprehensive PR information:
   ```bash
   gh pr view <PR_NUMBER> --json number,title,body,author,additions,deletions,files,commits,labels,reviewDecision
   ```

2. Get the PR diff:
   ```bash
   gh pr diff <PR_NUMBER>
   ```

3. Get the list of changed files:
   ```bash
   gh pr view <PR_NUMBER> --json files --jq '.files[].path'
   ```

4. Get the HEAD commit SHA (needed for inline comments):
   ```bash
   gh pr view <PR_NUMBER> --json headRefOid -q .headRefOid
   ```

5. Get the repository owner/name:
   ```bash
   gh repo view --json nameWithOwner -q .nameWithOwner
   ```

Store `COMMIT_SHA` and `OWNER_REPO` — they are required for posting inline comments in Step 7.

Now proceed to Step 5 based on the selected review level.

---

## Step 5: Perform Review Based on Level

### For LOW Level Review:
**Context Needed**: PR diff only (already fetched in Step 4)

**Analysis Focus**:
- Code style and formatting consistency
- Obvious syntax errors or typos
- Basic code smells (long functions, magic numbers, etc.)
- Simple logic errors
- Naming conventions
- Comment quality

**Process**:
1. Analyze the diff line by line
2. Identify issues in each category
3. Keep feedback concise and specific
4. Skip to Step 6

---

### For MEDIUM Level Review:
**Context Needed**: PR diff + immediately affected files

**Analysis Focus**:
- Breaking changes (API modifications, signature changes)
- Missing feature implementation (incomplete features)
- API contract validation (interfaces, types)
- Import/dependency issues
- Type safety concerns
- Error handling in changed code
- Edge cases in the modified logic

**Process**:
1. Identify files that are directly imported by or import the changed files
2. Read those files to understand the immediate context
3. Check for:
   - Functions/methods called in the PR - do they exist?
   - New imports - are they valid?
   - Changed interfaces/types - what uses them?
   - Removed code - is it still referenced elsewhere?
4. Analyze the changes for breaking changes and missing features
5. Skip to Step 6

**File Discovery Strategy**:
Use `grep` to find files that import the changed files, or files imported by the changed files. Focus on:
- Same directory files
- Direct parent/child relationships
- Test files for the changed code

---

### For CRITICAL Level Review:
**Context Needed**: PR diff + comprehensive codebase analysis

**Analysis Focus**:
- Design pattern adherence (factory, singleton, observer, etc.)
- Architecture compliance (layering, separation of concerns)
- Best practices validation (DRY, SOLID, etc.)
- Security concerns (injection, XSS, authentication, authorization)
- Performance implications (N+1 queries, memory leaks, unnecessary operations)
- Test coverage (are new features tested? are edge cases covered?)
- Documentation completeness (JSDoc, README updates)
- Edge case handling
- Error handling patterns (consistent error handling)
- Code duplication
- Scalability concerns

**Process**:
1. Understand the project structure by exploring key directories
2. Identify the architectural patterns used in the codebase:
   - Look for configuration files (package.json, tsconfig.json, etc.)
   - Check for architectural documents or README files
   - Identify the framework/library being used
3. For each changed file:
   - Read the entire file to understand its purpose
   - Find related files (services, models, controllers, tests)
   - Check if design patterns are followed consistently
   - Verify error handling matches existing patterns
   - Check for security vulnerabilities
   - Assess performance impact
4. Check test coverage:
   - Look for test files related to the changes
   - Verify new code has tests
   - Check if edge cases are tested
5. Check documentation:
   - Are there JSDoc comments for new functions?
   - Is the README updated if needed?
   - Are breaking changes documented?
6. Proceed to Step 6

**Exploration Strategy**:
- Use file system tools to understand project structure
- Use grep to find usage patterns
- Read configuration files to understand tooling
- Look for similar patterns elsewhere in the codebase
- Check commit history context if relevant

---

## Step 6: Structure Findings for Inline Comments

> **IMPORTANT**: Each finding must reference a line that exists in the PR diff. The GitHub API only allows inline comments on lines that appear in the diff. If a finding relates to code not in the diff, include it in the review summary body instead.

For each issue found, produce a structured finding:

```
### Finding
- **file:** <relative path to file>
- **line:** <line number in the new version of the file>
- **end_line:** <end line number, only if the finding spans multiple lines>
- **severity:** critical | major | minor
- **issue:** <1 sentence — what is wrong>
- **impact:** <1 sentence — why it matters>
- **fix:**
\```<lang>
<corrected code>
\```
```

### Inline Comment Body Format

Each finding becomes an inline comment with this body:

```
<SEVERITY_EMOJI> **<severity>** — <issue>

**Impact:** <impact>

**Fix:**
\```<lang>
<corrected code>
\```
```

Severity emoji mapping:
- `🔴 critical` — must fix before merge
- `🟠 major` — should fix, risk if ignored
- `🟡 minor` — nice to fix, low risk

### Review Summary Body

The top-level review body (not an inline comment) should be a brief summary:

```
## Review: <PR_TITLE>

**Level:** <low/medium/critical>
**Findings:** 🔴 <N> critical · 🟠 <N> major · 🟡 <N> minor

**Verdict:** <APPROVE / REQUEST CHANGES / COMMENT>

<2-3 sentence summary of the most important themes>
```

### Positives (in summary body)

If noteworthy things were done well, add a brief `**Positives:**` line in the summary body. Keep it specific and short.

Once findings are structured, proceed to Step 7.

---

## Step 7: Output the Review

Based on the user's selected output format:

### For LOCAL format:
1. Save all findings as a markdown file named: `pr-<PR_NUMBER>-review-<TIMESTAMP>.md`
2. Use the finding format from Step 6 as-is (readable in markdown)
3. Inform the user where the file was saved
4. Done!

---

### For DRAFT format (pending review with inline comments):

1. Construct a JSON payload file at `/tmp/pr-<PR_NUMBER>-review.json` with this structure:

```json
{
  "commit_id": "<COMMIT_SHA from Step 4>",
  "body": "<review summary from Step 6>",
  "comments": [
    {
      "path": "<file path>",
      "line": <line_number>,
      "side": "RIGHT",
      "body": "<formatted inline comment body>"
    },
    {
      "path": "<file path>",
      "start_line": <start_line>,
      "start_side": "RIGHT",
      "line": <end_line>,
      "side": "RIGHT",
      "body": "<formatted inline comment body>"
    }
  ]
}
```

**Rules for the `comments` array:**
- `line` is the line number in the **new version** of the file (RIGHT side of the diff)
- For multi-line findings, include `start_line` and `start_side` alongside `line` and `side`
- For single-line findings, only `line` and `side` are needed
- `side` is always `"RIGHT"` unless commenting on deleted code (use `"LEFT"`)
- Only include comments on lines that appear in the PR diff

2. Submit as a **PENDING** review (no `event` field = draft):

```bash
gh api \
  --method POST \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  /repos/<OWNER_REPO>/pulls/<PR_NUMBER>/reviews \
  --input /tmp/pr-<PR_NUMBER>-review.json
```

3. Save the returned review `id` from the response

4. Inform the user:
   - The review is posted as a **pending draft** — only visible to them
   - They can view, edit, or delete individual comments in the GitHub PR UI
   - When ready, they can publish it from GitHub or you can submit it with a follow-up command

5. Clean up: `rm /tmp/pr-<PR_NUMBER>-review.json`

6. Done!

---

### For DIRECT format (submit immediately with inline comments):

1. Determine the review decision based on findings:
   - If any `critical` findings → `REQUEST_CHANGES`
   - If only `major` or `minor` findings → `COMMENT`
   - If no findings or explicitly positive → `APPROVE` (only if the user confirms)

2. Construct the same JSON payload as the DRAFT format, but **include the `event` field**:

```json
{
  "commit_id": "<COMMIT_SHA>",
  "body": "<review summary>",
  "event": "REQUEST_CHANGES",
  "comments": [ ... ]
}
```

Valid `event` values: `APPROVE`, `REQUEST_CHANGES`, `COMMENT`

3. Submit the review:

```bash
gh api \
  --method POST \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  /repos/<OWNER_REPO>/pulls/<PR_NUMBER>/reviews \
  --input /tmp/pr-<PR_NUMBER>-review.json
```

4. Clean up: `rm /tmp/pr-<PR_NUMBER>-review.json`

5. Inform the user that the review has been submitted with the decision
6. Provide the PR URL: `gh pr view <PR_NUMBER> --json url -q .url`
7. Done!

---

## Submitting a Pending Draft Review

If the user previously chose `draft` and now wants to submit it:

1. Find the pending review:
   ```bash
   gh api /repos/<OWNER_REPO>/pulls/<PR_NUMBER>/reviews \
     --jq '.[] | select(.state == "PENDING") | {id: .id, body: .body}'
   ```

2. Submit it:
   ```bash
   gh api \
     --method POST \
     -H "Accept: application/vnd.github+json" \
     -H "X-GitHub-Api-Version: 2022-11-28" \
     /repos/<OWNER_REPO>/pulls/<PR_NUMBER>/reviews/<REVIEW_ID>/events \
     -f event="COMMENT"
   ```

   Use `REQUEST_CHANGES` or `APPROVE` instead of `COMMENT` based on findings.

---

## Error Handling

At any step, if an error occurs:

1. **GitHub CLI not installed or authenticated**:
   - Inform the user
   - Provide instructions: `gh auth login`

2. **Not in a git repository**:
   - Inform the user they need to run this command from within a git repository

3. **PR not found**:
   - Show available PRs and ask the user to select one

4. **Permission denied when submitting review**:
   - Inform the user they may not have permission to review this PR
   - Suggest saving as local file instead

5. **Inline comment on non-diff line (422 error)**:
   - The GitHub API only allows comments on lines in the diff
   - If a comment fails, move it to the review summary body instead
   - Retry the submission without the failing comment

6. **Network errors**:
   - Retry once
   - If still fails, offer to save the review locally

---

## Notes

- Every finding gets an inline comment on the exact line — no bundled walls of text
- Keep comment bodies short and scannable: severity → issue → impact → fix
- Only comment on lines that appear in the PR diff
- For issues about missing code (e.g., missing tests), put them in the review summary body
- Be thorough but concise — the developer should understand the issue in 5 seconds
- Always be constructive and professional in tone
- Clean up temporary JSON files after submission
