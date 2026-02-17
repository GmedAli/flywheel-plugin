---
description: Review PRs with configurable depth and output options
---

# PR Review Command

This command will help you review Pull Requests with varying levels of depth and provide feedback through different channels.

## Step 1: Ask User for Configuration

Before we begin the review, I need to ask you a few questions to configure the review process:

**Question 1: What review level would you like?**
- `low` - Superficial review, focusing on code style, obvious errors, and simple code smells. No external context needed. Fast (~30 seconds).
- `medium` - Context-aware review focusing on breaking changes, missing features, and API contracts. Analyzes immediate context files. Token-efficient (~1-2 minutes).
- `critical` - In-depth comprehensive review checking design patterns, architecture, best practices, security, performance, and test coverage. Full codebase analysis (~3-5 minutes).

**Question 2: How would you like to receive the review?**
- `local` - Save the review as a markdown file in the current directory
- `draft` - Submit the review as a draft on GitHub (allows you to review before publishing)
- `direct` - Submit the review directly to GitHub

**Question 3: Should I include proposed solutions?**
- `yes` - Include code suggestions and proposed fixes for identified issues
- `no` - Only identify issues without providing solutions

**Question 4 (Optional): Which PR would you like to review?**
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

## Step 6: Structure the Review

Organize your findings into a structured review with the following sections:

### Review Structure:

```markdown
# PR Review: <PR_TITLE>

**Review Level**: <LOW/MEDIUM/CRITICAL>
**PR Number**: #<NUMBER>
**Reviewed by**: AI Assistant
**Date**: <CURRENT_DATE>

---

## Summary

<1-2 paragraph summary of the PR and overall assessment>

---

## Issues Found

### Critical Issues 🔴
<List of critical issues that must be addressed>

### Important Issues 🟡
<List of important issues that should be addressed>

### Minor Issues 🟢
<List of minor issues or suggestions>

---

## Detailed Review by File

### `<file_path_1>`

**Lines <start>-<end>**: <Issue description>
<If solutions are enabled, include proposed fix>

**Lines <start>-<end>**: <Issue description>
<If solutions are enabled, include proposed fix>

### `<file_path_2>`

...

---

## Positive Observations ✅

<List things that were done well>

---

## Recommendations

<Overall recommendations for improving the PR>

---

## Review Decision

<APPROVE / REQUEST CHANGES / COMMENT>
```

Once the review is structured, proceed to Step 7.

---

## Step 7: Output the Review

Based on the user's selected output format:

### For LOCAL format:
1. Save the review markdown to a file named: `pr-<PR_NUMBER>-review-<TIMESTAMP>.md`
2. Inform the user where the file was saved
3. Done!

---

### For DRAFT format:
1. Save the review to a temporary file
2. Submit as a draft review using:
   ```bash
   gh pr review <PR_NUMBER> --comment --body-file <temp_file>
   ```
3. Inform the user that the review has been submitted as a draft
4. Provide the URL to view the draft review on GitHub
5. Done!

---

### For DIRECT format:
1. Determine the review decision based on findings:
   - If critical issues found → REQUEST CHANGES
   - If no critical issues → COMMENT (neutral feedback)
   - If explicitly positive → APPROVE (only if the user confirms)

2. For code-specific comments, format them for GitHub:
   ```bash
   # For line-specific comments, use the GitHub review API
   gh api repos/{owner}/{repo}/pulls/<PR_NUMBER>/reviews \
     --method POST \
     --field event="COMMENT" \
     --field body="<review_summary>" \
     --field comments[][path]="<file_path>" \
     --field comments[][line]=<line_number> \
     --field comments[][body]="<comment_text>"
   ```

3. Submit the review:
   - If REQUEST CHANGES:
     ```bash
     gh pr review <PR_NUMBER> --request-changes --body "<summary>"
     ```
   - If COMMENT:
     ```bash
     gh pr review <PR_NUMBER> --comment --body "<summary>"
     ```
   - If APPROVE:
     ```bash
     gh pr review <PR_NUMBER> --approve --body "<summary>"
     ```

4. Inform the user that the review has been submitted
5. Provide the URL to view the review on GitHub
6. Done!

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

5. **Network errors**:
   - Retry once
   - If still fails, offer to save the review locally

---

## Notes

- Be thorough but concise in your feedback
- Focus on actionable items
- Provide context for why something is an issue
- If proposing solutions, ensure they are tested and correct
- Respect the token budget for each review level
- For critical reviews, prioritize the most impactful issues
- Always be constructive and professional in tone
