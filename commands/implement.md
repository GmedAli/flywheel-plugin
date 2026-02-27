---
description: Full feature implementation workflow — research, plan, propose, build, test
---

# Implement Feature

> **Personas active:**
> - `fw-researcher` — Phase 1b ecosystem research (libraries, patterns, security, pitfalls)
> - `fw-architect` — Phase 2 technical planning (approach comparison, ADRs, file impact map, risk register)

This command runs a structured 9-phase workflow to implement a feature end-to-end. Claude orchestrates specialized agents at each phase. **No code is written until you approve the proposal.**

---

## Step 0: Parse Input & Detect Scope

Parse the user's input:
- **Feature description**: the full text after `/fw:implement`
- If no description provided, ask: *"What feature would you like to implement?"*

**Detect scope** from keywords in the description:

| Scope | Trigger words | Effect |
|-------|--------------|--------|
| `small` | add, fix, tweak, update, rename, change, remove | Skip Phase 1 Gemini research + Phase 6 iteration loop |
| `medium` | implement, build, create, integrate, extend, refactor | All phases |
| `large` | architect, redesign, system, full, migration, overhaul | All phases + deeper research prompts |

Show the detected scope:
```
🎯 Feature: <description>
📐 Scope detected: MEDIUM — running full workflow
```

**Create session directory (per-project isolation):**
```bash
PROJECT_NAME="${FLYWHEEL_PROJECT:-$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")")}"
SESSION_DIR="$HOME/.flywheel/projects/$PROJECT_NAME/implement/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$SESSION_DIR"
```

Save `$SESSION_DIR/00-session.md` with:
- Feature description
- Scope
- Start timestamp
- Git branch (run `git branch --show-current`)
- Working directory

---

## Phase 1: Research 🔍

> *Inspired by the `probe` phase in claude-octopus embrace workflow*

**Goal:** Gather external ecosystem knowledge AND internal codebase context simultaneously.

### 1a — Codebase Scan (Claude, always runs)

You (Claude) scan the current project for:
- Existing patterns relevant to this feature (grep for related terms)
- Files likely to be affected
- Current conventions (naming, structure, error handling)
- Integration points (APIs, services, shared utilities)

Summarise findings in `$SESSION_DIR/01-research-codebase.md`.

### 1b — Ecosystem Research (medium + large only)

**Primary path — invoke `fw-researcher` persona:**
```
Task(fw-researcher): Research best practices, libraries, and patterns for: <FEATURE_DESCRIPTION>.

Detected technologies: <TECHNOLOGIES_FROM_CODEBASE_SCAN_AND_FEATURE_DESCRIPTION>

IMPORTANT: Use the context7-research skill — call Context7 MCP tools first for each detected
technology (max 3) to get official documentation before falling back to WebSearch.
Query template: "Best practices and API reference for implementing <FEATURE> with <library>"

Include:
1. Official documentation findings (Context7) — version-specific APIs and patterns
2. Recommended libraries/frameworks — rate each as ✅/⚠️/❌ with maintenance status
3. Common implementation patterns — with concrete examples
4. Known pitfalls and edge cases — specific and cited
5. Security considerations — mandatory, not optional
6. Performance implications — measurable characteristics

Stack context: <detected from codebase scan>
```

**Fallback — if fw-researcher not installed, run Gemini via dispatch.sh:**

Before dispatching to Gemini, enrich the prompt with Context7 documentation:
1. Identify technologies from the feature description and codebase scan (max 3)
2. For each, call `mcp__context7__resolve-library-id` then `mcp__context7__query-docs` with query: "Best practices and API reference for implementing <FEATURE> with <library>"
3. If Context7 returns results, prepend them to the Gemini prompt as shown below
4. If Context7 fails or returns nothing, skip silently and dispatch without enrichment

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh" "gemini" "OFFICIAL DOCUMENTATION CONTEXT (via Context7):
<Context7 findings, or omit this section if none>

---

Research best practices, libraries, and patterns for: <FEATURE_DESCRIPTION>. Focus on: (1) recommended libraries/frameworks, (2) common implementation patterns, (3) known pitfalls and edge cases, (4) security considerations, (5) performance implications. Be specific and actionable."
```

Save output to `$SESSION_DIR/01-research-ecosystem.md`.

### Phase 1 Summary

Print a brief summary:
```
✅ Phase 1 Complete — Research
   Codebase: <N> relevant files found, <key patterns noted>
   Ecosystem: <top 2-3 findings>
```

---

## Phase 2: Planning 🏗️

> *Inspired by the `grasp` phase — uses fw-architect persona*

**Goal:** Produce a technical plan with architecture decisions.

**Primary path — invoke `fw-architect` persona:**
```
Task(fw-architect): Based on the following context, produce a technical implementation plan.

FEATURE: <FEATURE_DESCRIPTION>

CODEBASE CONTEXT:
<contents of 01-research-codebase.md>

ECOSYSTEM RESEARCH:
<contents of 01-research-ecosystem.md, or 'N/A for small scope'>

Produce:
- Approach analysis table (2-3 options) + recommended choice with rationale
- Architecture Decision Record (ADR)
- File impact map (CREATE/MODIFY/DELETE with purpose)
- Risk register
- Integration checklist
- Effort estimate (honest — do not under-estimate)
```

**Fallback — if fw-architect not installed, run Codex:**
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh" "codex" "You are a backend architect. Based on the following context, produce a technical implementation plan.

FEATURE: <FEATURE_DESCRIPTION>

CODEBASE CONTEXT:
<contents of 01-research-codebase.md>

ECOSYSTEM RESEARCH:
<contents of 01-research-ecosystem.md, or 'N/A for small scope'>

Produce:
1. Recommended approach (with rationale)
2. Alternative approaches considered (and why rejected)
3. Files to create/modify (with purpose of each)
4. Key architectural decisions (ADRs)
5. Integration points and dependencies
6. Potential risks and mitigations
7. Rough effort estimate (hours)

Be specific to this codebase, not generic."
```

Save output to `$SESSION_DIR/02-plan.md`.

Print:
```
✅ Phase 2 Complete — Technical Plan ready
```

---

## Phase 3: Questions ❓

**Goal:** Identify gaps before committing to an approach. Ask only what's truly blocking.

You (Claude) analyse the research + plan and identify ambiguities. Then ask the user **at most 5 questions**, ranked by impact. Format them clearly:

```
🤔 Before I write the proposal, I need to clarify a few things:

1. [Most critical question — would change the approach entirely]
2. [Second question]
3. [Third question, if needed]
...

(Answer all, or type "skip" to proceed with assumptions)
```

Wait for the user's response. If they say "skip", note reasonable assumptions for each unanswered question.

Save questions + answers to `$SESSION_DIR/03-questions.md`.

---

## Phase 4: Proposal 📋

**Goal:** Produce a structured spec the user can approve or modify.

You (Claude) write the proposal using all context gathered so far. Save to `$SESSION_DIR/04-proposal.md` and display it to the user:

```markdown
# Implementation Proposal: <FEATURE_NAME>

## Summary
<1-2 sentence description of what will be built>

## Approach
<Chosen approach with rationale>

## Scope
- **In scope:** <what will be built>
- **Out of scope:** <explicitly excluded>

## Files to Change
| File | Action | Purpose |
|------|--------|---------|
| path/to/file.ts | CREATE | ... |
| path/to/other.ts | MODIFY | ... |

## Acceptance Criteria
- [ ] <Criterion 1 — testable>
- [ ] <Criterion 2 — testable>
- [ ] <Criterion 3 — testable>

## Risks & Mitigations
| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| ... | Low/Med/High | ... |

## Effort Estimate
~<N> hours

## Assumptions Made
<List any assumptions from Phase 3 "skip" answers>
```

---

## Phase 5: User Approval Gate ⛔

**This is a hard stop. No code is written until you approve.**

Ask:
```
📋 Proposal ready. How would you like to proceed?

  [approve]  — proceed to implementation
  [modify]   — tell me what to change (loops back to Phase 4)
  [cancel]   — exit without changes
```

- **approve** → continue to Phase 6
- **modify** → ask what to change, update the proposal, show it again, repeat Phase 5
- **cancel** → print "Implementation cancelled. Session saved to `$SESSION_DIR`." and stop

---

## Phase 6: Iteration 🔄

> *Inspired by the `tangle` phase — Codex proposes, Claude reviews*
> **Skipped for `small` scope**

**Goal:** Validate the implementation approach before writing any code. Max 3 rounds.

### Round loop (up to 3 times):

**Codex proposes** the detailed implementation approach (pseudocode + file structure, no actual code yet):
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh" "codex" "Based on this approved proposal, describe in detail HOW you would implement it — file by file, function by function. Use pseudocode where helpful. Do NOT write the actual implementation yet.

PROPOSAL:
<contents of 04-proposal.md>"
```

**Claude reviews** the proposed approach for:
- Correctness (does it actually satisfy the acceptance criteria?)
- Security (any obvious vulnerabilities?)
- Edge cases (what's missing?)
- Consistency with existing codebase patterns

If issues found, feed them back to Codex for another round. If approved (or after 3 rounds), proceed.

Save final iteration output to `$SESSION_DIR/06-iteration.md`.

Print:
```
✅ Phase 6 Complete — Approach validated after <N> round(s)
```

---

## Phase 7: Implementation 🛠️

> *Inspired by the `tangle` phase — Codex with acceptEdits*

**Goal:** Write the actual code.

Run Codex with full implementation instructions:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh" "codex" "Implement the following feature exactly as specified. Write production-ready code following the existing codebase patterns.

PROPOSAL:
<contents of 04-proposal.md>

APPROVED APPROACH:
<contents of 06-iteration.md, or 'See proposal' for small scope>

CODEBASE CONTEXT:
<contents of 01-research-codebase.md>

Requirements:
- Follow existing naming conventions and code style
- Add error handling consistent with existing patterns
- Add inline comments only where logic is non-obvious
- Do NOT add placeholder TODOs — implement fully or flag explicitly"
```

Save output to `$SESSION_DIR/07-implementation.md`.

Print:
```
✅ Phase 7 Complete — Implementation written
```

---

## Phase 8: Testing 🧪

> *Inspired by tdd-orchestrator persona*

**Goal:** Write and validate tests for the implementation.

### 8a — Codex writes tests

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh" "codex" "You are a TDD expert. Write comprehensive tests for the following implementation.

IMPLEMENTATION:
<contents of 07-implementation.md>

ACCEPTANCE CRITERIA:
<acceptance criteria from 04-proposal.md>

Write:
1. Unit tests for each new function/method
2. Integration tests for the main user flows
3. Edge case tests (empty inputs, errors, boundary values)
4. Use the existing test framework and conventions in this project

After writing the tests, run them and report results."
```

### 8b — Claude reviews coverage

Review the test output and check:
- Are all acceptance criteria covered by at least one test?
- Are the critical edge cases tested?
- Flag any gaps

Save to `$SESSION_DIR/08-testing.md`.

Print:
```
✅ Phase 8 Complete — Tests written and reviewed
   Coverage: <summary of what's tested>
   Gaps: <any flagged gaps>
```

---

## Phase 9: Return ✅

**Goal:** Synthesise everything into a clear summary for the user.

You (Claude) produce the final report:

```markdown
# ✅ Implementation Complete: <FEATURE_NAME>

## What Was Built
<2-3 sentence summary>

## Files Changed
| File | Action | Description |
|------|--------|-------------|
| ... | CREATED/MODIFIED | ... |

## Test Results
- Tests written: <N>
- Tests passing: <N>
- Coverage gaps: <any noted>

## Acceptance Criteria
- [x] <Criterion 1>
- [x] <Criterion 2>
- [ ] <Any not met — with explanation>

## Known Limitations
<Anything explicitly out of scope or deferred>

## Suggested Next Steps
- Run `/fw:review` to get a code review before merging
- Consider delegating performance testing: `/fw:delegate using codex benchmark <feature>`
- Open PR: `gh pr create --title "<feature>" --body "Implements <description>"`

## Session Files
All phase outputs saved to: <SESSION_DIR>
```

Save to `$SESSION_DIR/09-return.md`.

---

## Error Handling

- **Phase fails** (dispatch.sh exits non-zero): Show the error, offer to retry or skip the phase
- **Codex not available**: Fall back to Claude for Phases 2, 6, 7, 8 with a note
- **Gemini not available**: Skip Phase 1b, note the gap in research
- **User cancels at any phase**: Save session state and print the session directory path
- **Session interrupted**: User can resume by referencing the session directory

---

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `FLYWHEEL_MAX_TIMEOUT` | `1800` | Max seconds per agent call (30 min) |
| `FLYWHEEL_CODEX_SANDBOX` | `workspace-write` | Codex sandbox mode |
| `FLYWHEEL_SHOW_THINKING` | `true` | Show Codex reasoning output |
| `FLYWHEEL_PROJECT` | `<git repo name>` | Override project name for session isolation |
| `FLYWHEEL_IMPLEMENT_DIR` | `~/.flywheel/projects/<project>/implement` | Where session files are saved |
