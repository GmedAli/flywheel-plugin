---
description: Full feature implementation workflow — research, plan, propose, build, test
---

# Implement Feature

> **Personas active:**
> - `fw-researcher` — Phase 1b ecosystem research (libraries, patterns, security, pitfalls)
> - `fw-architect` — Phase 2 technical planning (approach comparison, ADRs, file impact map, risk register)

This command runs a structured 9-phase workflow to implement a feature end-to-end. Claude orchestrates specialized agents at each phase. **No code is written until you approve the proposal.**

> **Design-aware:** If a prior `/fw:design` run produced a `DESIGN-PLAN.md`, this command detects it and fast-tracks through research and planning — jumping straight to a quick technical prep and then implementation.

---

## Team Configuration

> **Mode**: `team` when agent teams enabled; `sequential` fallback (identical behavior)
> **Template**: `research-and-plan` (from config/team-templates.yaml)
> **Minimum scope**: `medium` — skip teams for `small` scope
> **Detection**: `scripts/team-detect.sh`

| Role | Persona | Phase(s) | Task | Parallel With |
|------|---------|----------|------|---------------|
| researcher | fw-researcher | 1b | Ecosystem research | Phase 1a (lead) |
| architect | fw-architect | 2 | Technical planning | — (after 1a+1b) |
| test-writer | fw-test-generator | 8 | Test writing | Phase 7 (codex) |

### Parallel Phase Groups

| Group | Phases | Members | Prerequisite |
|-------|--------|---------|-------------|
| A | 1a + 1b | lead + researcher | None |
| B | 2 | architect | Group A complete |
| C | 7 + 8 | lead (codex) + test-writer | Phase 5 user approval |

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

**Detect agent teams availability** (for medium + large scope):
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/team-detect.sh" 2>&1
```
Set `TEAM_MODE=true` if exit code is 0, `TEAM_MODE=false` otherwise. Display the result line to the user.

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

### Design Plan Detection

Check if a prior `/fw:design` run exists:

1. Look for `DESIGN-PLAN.md` in the project root
2. If not found, check for the most recent session in `~/.flywheel/projects/$PROJECT_NAME/design/` that contains a `05-plan.md`

If a design plan is found:

```
📋 Existing design plan detected: <path to DESIGN-PLAN.md or 05-plan.md>
⚡ Fast-tracking — skipping research & planning phases
```

Set `DESIGN_FAST_TRACK=true` and load the plan contents into `$DESIGN_PLAN`.

Ask the user:
```
Found an existing design plan. How would you like to proceed?

  [use]     — use this plan and go straight to implementation
  [review]  — show the plan summary first, then decide
  [ignore]  — discard it and run the full workflow from scratch
```

- **use** → jump to **Phase 4b: Technical Prep** (below)
- **review** → display the plan's Section 1 (Requirements) and Section 4 (Implementation Plan / Task Breakdown), then ask `[use]` or `[ignore]`
- **ignore** → set `DESIGN_FAST_TRACK=false`, continue to Phase 1 as normal

If no design plan is found, set `DESIGN_FAST_TRACK=false` and continue to Phase 1.

---

## Phase 4b: Technical Prep (design fast-track only) 🔧

> **Only runs when `DESIGN_FAST_TRACK=true`** — replaces Phases 1-4.

**Goal:** Bridge the gap between the design plan and implementation. The design plan has the *what* and *why* — this phase fills in any remaining *how*.

### 4b-i — Quick Codebase Reconciliation

You (Claude) do a focused scan:
- Verify the files listed in the design plan's Impact Overview still exist and haven't changed significantly since the plan was written
- Check for any new files or changes that might affect the plan (e.g., someone else merged related work)
- Confirm the task breakdown in Section 4 is still accurate

If discrepancies are found:
```
⚠️  Codebase changes detected since design plan was written:
   - <file>: <what changed>
   - <file>: <new file not in plan>

Adjusting implementation approach accordingly.
```

### 4b-ii — Technical Gap Fill (medium + large only)

For anything the design plan left abstract (e.g., "add validation logic", "integrate with API"), resolve to concrete implementation details:
- Exact function signatures and types
- Specific imports and dependencies
- Error handling patterns matching the codebase

### 4b-iii — Generate Proposal from Design Plan

Transform the design plan into the standard proposal format and save to `$SESSION_DIR/04-proposal.md`:

```markdown
# Implementation Proposal: <FEATURE_NAME>

## Summary
<From design plan Section 1 — Requirements / What We're Building>

## Approach
<From design plan Section 2 — Solution Overview>

## Scope
- **In scope:** <from design plan Requirements>
- **Out of scope:** <from design plan Out of Scope>

## Files to Change
<From design plan Section 3 — Impact Overview, converted to table format>

## Acceptance Criteria
<From design plan Success Criteria>

## Task Breakdown
<From design plan Section 4 — preserved as-is, this is the implementation roadmap>

## Risks & Mitigations
<From design plan Section 5>

## Technical Notes
<Any findings from 4b-i and 4b-ii — codebase reconciliation and gap fill>
```

Save codebase reconciliation to `$SESSION_DIR/01-research-codebase.md` (for Phase 7 context).

Print:
```
✅ Technical Prep Complete — Design plan adapted for implementation
   Files verified: <N>/<total in plan>
   Discrepancies: <count or "none">
```

→ **Jump directly to Phase 5 (User Approval Gate)**

---

## Phase 1: Research 🔍

> **Skipped when `DESIGN_FAST_TRACK=true`** — design plan already covers this.

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

**[TEAM MODE — researcher teammate | runs in parallel with Phase 1a]**

If `TEAM_MODE=true` and scope is `medium` or `large`:

Create a team and spawn a researcher teammate:
```
Create an agent team for this implementation session.

Spawn a teammate named 'researcher' with the following context:

PERSONA IDENTITY:
<contents of agents/personas/fw-researcher.md>

PROJECT CONTEXT:
- Feature: <FEATURE_DESCRIPTION>
- Detected technologies: <from Phase 1a codebase scan>
- Session directory: <SESSION_DIR>

TASK:
Research best practices, libraries, and patterns for: <FEATURE_DESCRIPTION>.

IMPORTANT: Use Context7 MCP tools first for each detected technology (max 3).
Query template: "Best practices and API reference for implementing <FEATURE> with <library>"

Include:
1. Official documentation findings (Context7) — version-specific APIs and patterns
2. Recommended libraries/frameworks — rate each as ✅/⚠️/❌ with maintenance status
3. Common implementation patterns — with concrete examples
4. Known pitfalls and edge cases — specific and cited
5. Security considerations — mandatory, not optional
6. Performance implications — measurable characteristics

DELIVERABLE:
Save findings to: <SESSION_DIR>/01-research-ecosystem.md
Mark your task complete when done and notify the lead.
```

Lead continues Phase 1a codebase scan in parallel.
Wait for researcher teammate to complete, then proceed to Phase 2.

---

**[SEQUENTIAL MODE — fallback when agent teams disabled]**

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

---

*(End of sequential mode fallback for Phase 1b)*

### Phase 1 Summary

Print a brief summary:
```
✅ Phase 1 Complete — Research
   Codebase: <N> relevant files found, <key patterns noted>
   Ecosystem: <top 2-3 findings>
```

---

## Phase 2: Planning 🏗️

> **Skipped when `DESIGN_FAST_TRACK=true`** — design plan already covers this.
> *Inspired by the `grasp` phase — uses fw-architect persona*

**Goal:** Produce a technical plan with architecture decisions.

**Sequential Thinking** (skip for `small` scope; activate for `medium` and `large`):

Before tasking the architect, use structured reasoning to map integration risks and dependencies:

```
mcp__sequential-thinking__sequentialthinking({
  thought: "What are the key integration risks and dependencies for this feature?",
  thoughtNumber: 1,
  totalThoughts: 5,
  nextThoughtNeeded: true
})
```

Continue until `nextThoughtNeeded: false` or 8 thoughts reached. When complete, write a **Sequential Analysis Summary** (2-4 sentences) and include it in the architect prompt below as `SEQUENTIAL ANALYSIS: <summary>`.

If `mcp__sequential-thinking__sequentialthinking` is unavailable, skip this block silently.

**[TEAM MODE — architect teammate | runs after researcher completes]**

If `TEAM_MODE=true` and scope is `medium` or `large`:

Spawn an architect teammate (require plan approval):
```
Spawn a teammate named 'architect'. Require plan approval before they make any changes.

PERSONA IDENTITY:
<contents of agents/personas/fw-architect.md>

PROJECT CONTEXT:
- Feature: <FEATURE_DESCRIPTION>
- Session directory: <SESSION_DIR>

SEQUENTIAL ANALYSIS:
<summary from sequential thinking block, or omit if skipped>

CODEBASE CONTEXT:
<contents of SESSION_DIR/01-research-codebase.md>

ECOSYSTEM RESEARCH:
<contents of SESSION_DIR/01-research-ecosystem.md>

TASK:
Produce a technical implementation plan. Include:
- Approach analysis table (2-3 options) + recommended choice with rationale
- Architecture Decision Record (ADR)
- File impact map (CREATE/MODIFY/DELETE with purpose)
- Risk register
- Integration checklist
- Effort estimate (honest — do not under-estimate)

DELIVERABLE:
Save output to: <SESSION_DIR>/02-plan.md
```

Lead reviews the architect's plan (plan approval mode):
- If plan looks sound → approve it
- If plan needs revision → reject with specific feedback, architect revises
- When approved → proceed to Phase 3

---

**[SEQUENTIAL MODE — fallback when agent teams disabled]**

**Primary path — invoke `fw-architect` persona:**
```
Task(fw-architect): Based on the following context, produce a technical implementation plan.

FEATURE: <FEATURE_DESCRIPTION>

SEQUENTIAL ANALYSIS:
<summary from sequential thinking block above, or omit if skipped>

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

---

*(End of sequential mode fallback for Phase 2)*

Print:
```
✅ Phase 2 Complete — Technical Plan ready
```

---

## Phase 3: Questions ❓

> **Skipped when `DESIGN_FAST_TRACK=true`** — design plan already resolved open questions.

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

> **Skipped when `DESIGN_FAST_TRACK=true`** — proposal is generated from design plan in Phase 4b-iii instead.

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

**[TEAM MODE — test-writer teammate | runs in parallel with Phase 7]**

If `TEAM_MODE=true` and a team is active:

While Phase 7 implementation is running via dispatch.sh (codex), also instruct the team:
```
Spawn a teammate named 'test-writer' to begin test scaffolding in parallel.

PERSONA IDENTITY:
<contents of agents/personas/fw-test-generator.md>

PROJECT CONTEXT:
- Session directory: <SESSION_DIR>

TASK:
Begin writing test scaffolding based on the approved proposal and acceptance criteria.
Once the implementation (Phase 7) is marked complete, write full tests against the actual code.

PROPOSAL:
<contents of SESSION_DIR/04-proposal.md>

ACCEPTANCE CRITERIA:
<acceptance criteria from proposal>

DELIVERABLE:
Save test output to: <SESSION_DIR>/08-testing.md
Mark your task complete when done.
```

Lead synthesizes both the implementation result (Phase 7) and test-writer output for Phase 9.

---

**[SEQUENTIAL MODE — fallback (or when running after Phase 7 in team mode)]**

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

**[TEAM MODE cleanup]** If a team was active during this session:
```
Clean up the team. Shut down all remaining teammates first, then clean up shared team resources.
```

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
