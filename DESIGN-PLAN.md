# Design Plan: `/fw:reflect` Command

> Produced by `fw-architect` | 2026-03-02
> Status: Ready for implementation review

---

## 1. Requirements

### What We Are Building

A new flywheel command `/fw:reflect` that performs in-depth, multi-dimensional quality reflection on any user-defined scope. Unlike `/fw:review` (PR-bound, inline comment output) or `/fw:harden` (security-only), this command is scope-agnostic, aspect-selectable, and produces a narrative report with severity-sorted findings plus observed strengths.

### Success Criteria

1. User can reflect on any scope: single file, module, staged changes, branch diff, or full project
2. User can select which quality aspects to analyze (or accept all)
3. Output is a human-readable narrative report saved to session dir and displayed inline
4. Findings are sorted by severity: critical > high > mid > low
5. Report always includes concrete strengths alongside concerns
6. Large scopes delegate to codex sub-agents via `dispatch.sh`; small scopes stay in-process
7. User gate offers accept / deeper / implement / delegate handoff
8. Command follows all established flywheel conventions (YAML frontmatter, phased structure, session dir, error handling, env vars)

### Out of Scope

- **Code modification**: this is a read-only diagnostic command
- **PR integration**: no GitHub API calls, no inline comments (that is `/fw:review`)
- **Automated fix generation**: recommendations are guidance, not patches (that is `/fw:harden` or `/fw:implement`)
- **New scripts**: no new shell scripts needed; `dispatch.sh` already handles sub-agent orchestration
- **Config changes**: no changes to `config/agents.yaml`; the new persona is a Claude persona, not a dispatch agent

### Constraints

- Must use `dispatch.sh` for all sub-agent spawning (established in `/Users/dali/Documents/GitHub/flywheel-plugin/scripts/dispatch.sh`)
- Must follow the session directory pattern: `~/.flywheel/projects/<project>/reflect/<timestamp>/`
- Must follow the YAML frontmatter + phased structure used by all commands in `/Users/dali/Documents/GitHub/flywheel-plugin/commands/`
- Persona must follow the frontmatter schema established in `/Users/dali/Documents/GitHub/flywheel-plugin/agents/personas/fw-code-reviewer.md` (name, description, model, memory, tools, when_to_use, avoid_if, examples)
- Severity labels must use the 4-tier system (critical/high/mid/low) distinct from the review command's 3-tier (critical/major/minor) to reinforce that reflect is a different output mode

---

## 2. Solution Overview

### Approach

`/fw:reflect` is a 5-phase read-only command that:

1. **Parses** scope and aspect selection from user input (Phase 0)
2. **Resolves** the exact file list via git/glob (Phase 1)
3. **Analyzes** each selected aspect via structured prompts, delegating to codex for large scopes (Phase 2)
4. **Synthesizes** raw findings into a deduplicated, severity-sorted narrative with strengths and patterns (Phase 3, driven by `fw-reflector` persona)
5. **Presents** the final report and offers a user gate with handoff options (Phases 4-5)

### Architecture Sketch

```
User → /fw:reflect <scope> [aspects]
  │
  ├─ Phase 0: Parse scope + aspects → create $SESSION_DIR
  ├─ Phase 1: Resolve files → 01-scope.md
  ├─ Phase 2: Per-aspect analysis
  │   ├─ quick depth  → Claude reads files directly
  │   ├─ standard     → Claude + targeted dispatch.sh codex
  │   └─ deep         → dispatch.sh codex per chunk (fallback: claude)
  │   └─ → 02-analysis-raw.md
  ├─ Phase 3: fw-reflector synthesizes → 03-synthesis.md
  ├─ Phase 4: Report generation → 04-report.md (displayed to user)
  └─ Phase 5: User gate
      ├─ [accept]    → save, done
      ├─ [deeper]    → re-run Phase 2 on subset (max 2 rounds)
      ├─ [implement] → hand off to /fw:implement
      └─ [delegate]  → hand off to /fw:delegate
```

### Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Persona model | `sonnet` | Matches all non-architectural personas (`fw-code-reviewer`, `fw-researcher`, `fw-test-generator`). Opus is reserved for `fw-architect` which makes irreversible design decisions. Reflection is synthesis, not architecture. |
| Severity tiers | 4-tier (critical/high/mid/low) | Differentiates from review's 3-tier. Matches `/fw:harden` severity model for consistency across diagnostic commands. |
| Delegation threshold | >5 files = standard, >20 = deep | Matches the scope-sizing pattern in harden.md (file/module/project) while adding explicit file-count thresholds for dispatch decisions. |
| Aspect prompt structure | Embedded in command markdown | Follows harden.md pattern where OWASP scan prompts are embedded directly in the command file, not externalized. Keeps the command self-contained. |
| Sub-agent provider | codex primary, claude fallback | Matches harden.md Phase 1/4c pattern. Codex for heavy analysis; Claude fallback when codex unavailable. |
| Report format | Narrative markdown with severity buckets | Core differentiator from review (inline comments) and harden (security table). Narrative prose makes this useful for team-wide quality discussions. |
| Deeper re-entry | Max 2 rounds | Prevents infinite loops. User can always re-invoke the full command if needed. |

### New Dependencies

None. All infrastructure (`dispatch.sh`, session dirs, persona install) already exists.

---

## 3. Impact Overview

### Files to Create

| File | Purpose |
|------|---------|
| `commands/reflect.md` | The command workflow definition (5 phases + step 0) |
| `agents/personas/fw-reflector.md` | Synthesis persona for Phase 3-4 (quality consultant identity) |

### Files to Modify

| File | Change | Why |
|------|--------|-----|
| `scripts/install-personas.sh` | No change needed | Script already globs `agents/personas/fw-*.md` and installs all matches |

### Files Unchanged (verified)

- `scripts/dispatch.sh` -- already handles codex/claude/gemini routing
- `config/agents.yaml` -- personas are not dispatch agents; no entry needed
- `.claude-plugin/plugin.json` -- no version bump for a new command (convention: commands are additive)
- `CLAUDE.md` -- could optionally add reflect to the overview, but not required for function

---

## 4. Implementation Plan

### Task 1: Create `fw-reflector` Persona

**What:** Write the persona file following the established frontmatter schema.

**File:** `/Users/dali/Documents/GitHub/flywheel-plugin/agents/personas/fw-reflector.md`

**Depends on:** Nothing

**Specification:**

```yaml
---
name: fw-reflector
description: >
  Quality reflection specialist for the flywheel-plugin system. Synthesizes
  multi-dimensional analysis findings into narrative reports that balance
  strengths with concerns, sort by severity, and surface systemic patterns.
  Use PROACTIVELY when aggregating quality analysis results into a cohesive
  report for developers or team leads.
model: sonnet
memory: project
tools: ["Read", "Glob", "Grep", "Bash", "Task(Explore)"]
when_to_use: |
  - /fw:reflect command (primary consumer) — synthesis and report phases
  - Aggregating findings from multiple analysis passes into a unified view
  - Producing quality narratives for team review or retrospective
  - Identifying systemic patterns across disparate code quality findings
avoid_if: |
  - Inline PR review (use fw-code-reviewer)
  - Security-specific audit (use fw-security-auditor)
  - Architecture decisions (use fw-architect)
  - Implementation or code generation (use codex via /fw:implement)
examples:
  - prompt: "Synthesize these raw findings into a reflection report"
    outcome: "Narrative report with severity-sorted findings, strengths, patterns, and recommendations"
  - prompt: "Identify systemic quality patterns across auth module analysis"
    outcome: "3 recurring themes with evidence, linked recommendations"
---
```

**Identity section:** Quality consultant who sees the full picture. Balances honesty about weaknesses with recognition of strengths. Communicates to developers, not to auditors. Uses narrative prose where it adds clarity, structured lists where it adds scannability.

**Non-negotiables:**
- Every finding must cite specific evidence (file:line when available)
- Every report must include strengths (minimum 3, maximum 5)
- Severity must be calibrated honestly -- not everything is critical
- Patterns section is mandatory -- individual findings are less useful than systemic insights
- Recommendations must be actionable guidance, not vague advice
- Never produce inline-comment-style output -- this is a narrative report persona

**Validation checklist:**
- [ ] Frontmatter matches schema from `fw-code-reviewer.md` (name, description, model, memory, tools, when_to_use, avoid_if, examples)
- [ ] Model is `sonnet` (not `opus`)
- [ ] Tools list matches the read-only diagnostic pattern (same as `fw-debugger`)
- [ ] `avoid_if` section clearly distinguishes from `fw-code-reviewer` and `fw-security-auditor`
- [ ] Identity section establishes narrative voice distinct from review's inline-comment voice

---

### Task 2: Create `reflect.md` Command

**What:** Write the full command workflow following established phased conventions.

**File:** `/Users/dali/Documents/GitHub/flywheel-plugin/commands/reflect.md`

**Depends on:** Task 1 (persona must exist for the command to reference it)

**Structure:**

#### YAML Frontmatter

```yaml
---
description: Multi-dimensional quality reflection — scope-agnostic analysis with selectable aspects, severity-sorted findings, and narrative report
---
```

#### Persona Activation

```markdown
> **Persona active:** `fw-reflector` — quality consultant. Sees the full picture across selected dimensions. Balances strengths with concerns. Produces narrative reports, not inline comments.
```

#### Step 0: Parse Input & Configure

**Input parsing logic:**
1. Extract scope from args (file path, directory, "staged", "branch", "project", "all")
2. If no scope provided, prompt: *"What would you like to reflect on? (e.g. `src/auth/`, `staged`, `the whole project`, or a specific file)"*
3. Detect scope type using the same table as harden.md:

| Scope | Detection | Effect |
|-------|-----------|--------|
| `file` | Single file path | Analyze that file only |
| `module` | Directory/module name | Analyze that directory |
| `project` | "project", "all", "everything", or no path | Full codebase scan |
| `staged` | "staged", "diff", or `git diff --cached` has content | Only staged files |
| `branch` | Branch name or "current branch" | Files changed vs main |

4. Parse aspects from remaining args. Recognized keywords:
   - `implementation` / `quality` / `logic` -> aspect 1
   - `clean` / `readability` / `code quality` -> aspect 2
   - `design` / `patterns` / `architecture` -> aspect 3
   - `test` / `coverage` / `testing` -> aspect 4
   - `all` -> all four aspects

5. If no aspects detected in args, present selection prompt:
```
Which aspects would you like to analyze? (enter numbers, e.g. "1 3 4" or "all")

  1. Implementation quality -- logic, error handling, async patterns, edge cases
  2. Clean code -- naming, readability, DRY, SOLID, complexity
  3. Design patterns -- architectural alignment, pattern consistency, coupling
  4. Test coverage -- what's tested vs what's not, coverage gaps
```

6. Classify depth based on resolved file count:

| Depth | Trigger | Effect |
|-------|---------|--------|
| `quick` | Single file or staged with <5 files | Claude analyzes directly, no sub-agents |
| `standard` | Module/directory or staged with 5-20 files | Claude + targeted codex dispatch per aspect |
| `deep` | Project-wide or >20 files | Delegate to codex per analysis chunk (fallback: claude) |

7. Display classification:
```
🔍 Reflection: <scope description>
📐 Scope: MODULE -- src/auth/ (12 files)
🎯 Aspects: Implementation quality, Clean code, Design patterns
📊 Depth: STANDARD -- Claude + targeted sub-agents
```

8. Create session directory:
```bash
PROJECT_NAME="${FLYWHEEL_PROJECT:-$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")")}"
SESSION_DIR="$HOME/.flywheel/projects/$PROJECT_NAME/reflect/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$SESSION_DIR"
```

9. Save `$SESSION_DIR/00-session.md` with: scope description, aspects selected, depth, start timestamp, git branch, working directory, files in scope (list or count).

#### Phase 1: Scope Resolution

**Goal:** Resolve the exact list of files to analyze.

**Process:**
- `file` scope: Verify file exists, use as-is
- `module` scope: `find <dir> -type f -name '*.ts' -o -name '*.js' -o -name '*.py' ...` (language-aware extensions based on detected stack)
- `project` scope: Full project file listing, excluding `node_modules`, `.git`, `dist`, `build`, `vendor`, `__pycache__`
- `staged` scope: `git diff --cached --name-only`
- `branch` scope: `git diff main...HEAD --name-only` (fall back to `master` if `main` doesn't exist)

**Group files** by directory/domain for organized analysis (e.g., "auth/", "api/", "utils/").

**Save** file list to `$SESSION_DIR/01-scope.md` with grouping.

**Print:**
```
Phase 1 complete -- Scope resolved
  Files in scope: <N>
  Groups: <list of top-level groups>
```

#### Phase 2: Analysis

**Goal:** Run each selected aspect as an analysis pass over the resolved files.

**Dispatch strategy by depth:**

**Quick depth (Claude direct):**
- Claude reads the files directly (parallel Read calls)
- Runs each aspect prompt against the file contents inline
- No dispatch.sh calls

**Standard depth:**
- Claude reads files, then dispatches each selected aspect to codex via dispatch.sh
- Each aspect gets its own dispatch call with the relevant files as context
- If codex unavailable, Claude performs the analysis directly with a note about reduced depth

**Deep depth:**
- Chunk files into groups of ~10 files each
- Dispatch each chunk x aspect combination to codex via dispatch.sh
- If codex unavailable, fall back to claude sub-agents via dispatch.sh
- If neither available, Claude analyzes directly with a reduced-depth warning

**Aspect prompts (embedded in the command):**

**1. Implementation Quality:**
```
Analyze implementation quality in the following code. Focus on:
- Logic correctness (wrong conditions, off-by-one, inverted checks)
- Error handling (uncaught exceptions, empty catch blocks, silent failures)
- Async patterns (missing await, unhandled promises, race conditions)
- Edge cases (null/undefined guards, empty inputs, boundary values)
- Complexity (overly complex functions, hard-to-follow control flow)

For each finding: state the issue, the specific location (file:line if possible), severity (critical/high/mid/low), and what the ideal behavior should be.
Also note 2-3 specific implementation strengths you observe.
```

**2. Clean Code:**
```
Analyze code quality and readability in the following code. Focus on:
- Naming clarity (variables, functions, classes that misrepresent their purpose)
- DRY violations (duplicated logic that should be abstracted)
- SOLID violations (single responsibility, open/closed, etc.)
- Cognitive complexity (functions doing too many things, deep nesting)
- Magic numbers/strings (hardcoded values without named constants)
- Comment quality (missing explanations for non-obvious logic, outdated comments)

For each finding: state the issue, location, severity (critical/high/mid/low), and a brief suggestion.
Also note 2-3 specific clean code strengths you observe.
```

**3. Design Patterns:**
```
Analyze architectural alignment and design pattern usage in the following code. Focus on:
- Pattern consistency (is the codebase using a clear architectural style? does new code follow it?)
- Coupling and cohesion (tight coupling, inappropriate dependencies, god objects)
- Separation of concerns (business logic mixed with I/O, presentation, etc.)
- Abstraction levels (leaky abstractions, missing abstractions, wrong layer)
- Convention adherence (project naming, file structure, module organization)

For each finding: state the issue, location, severity (critical/high/mid/low), and which pattern would improve it.
Also note 2-3 specific architectural strengths you observe.
```

**4. Test Coverage:**
```
Analyze test coverage gaps in the following code. Focus on:
- Critical paths with no tests (business logic, auth, data mutations)
- Edge cases missing test coverage (error paths, empty inputs, boundary values)
- Test quality (tests testing implementation details instead of behavior)
- Brittleness (tests relying on internal state, timing, or external services)
- Coverage distribution (over-tested trivial code, under-tested complex logic)

For each finding: state what's untested, the risk if it breaks, severity (critical/high/mid/low), and what test to write.
Also note 2-3 specific testing strengths you observe.
```

**Dispatch pattern (for standard/deep):**
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh" "codex" "<ASPECT_PROMPT>

FILES IN SCOPE:
<file list>

CODEBASE CONTEXT:
<brief project description and conventions detected>" <context_files...>
```

**Collect** raw findings per aspect. **Save** to `$SESSION_DIR/02-analysis-raw.md`.

**Print per aspect:**
```
Phase 2 -- <Aspect Name> analysis complete
  Findings: <N> (critical: <N>, high: <N>, mid: <N>, low: <N>)
  Strengths noted: <N>
```

#### Phase 3: Synthesis

**Goal:** Aggregate, deduplicate, and sort all findings into a coherent synthesis.

**Process (Claude as fw-reflector):**
1. Read all raw findings from Phase 2
2. **Deduplicate**: Merge overlapping findings across aspects (e.g., same function flagged for complexity in both implementation and clean code)
3. **Sort** all findings into severity buckets: critical > high > mid > low
4. **Identify patterns**: Look for recurring themes across findings (e.g., "error handling is consistently weak", "naming conventions break down in utility modules")
5. **Extract strengths**: Collect top 3-5 strengths across all aspects, prioritizing specific and concrete observations
6. **Generate recommendations**: 3-5 actionable improvement recommendations that address systemic issues, not individual bugs. Each recommendation references specific findings.

**Save** to `$SESSION_DIR/03-synthesis.md`.

#### Phase 4: Report Generation

**Goal:** Produce the final human-readable report.

**Report template:**

```markdown
# Reflection Report: <scope>

> Generated by `/fw:reflect` | <DATE>
> Aspects: <selected aspects> | Depth: <quick/standard/deep>
> Files analyzed: <N>

---

## Summary

<3-4 sentence overview of the overall quality picture. Honest and specific.
Name the single biggest strength and the single biggest concern.>

---

## Strengths

<Bullet list of 3-5 specific strengths. Concrete -- name actual files, functions,
or patterns. Not generic praise.>

---

## Findings

### Critical
<Each finding: bold title, 1-2 sentence description, location (file:line), why it matters>

### High
<Same format>

### Mid
<Same format>

### Low
<Same format>

*(Empty severity buckets are omitted.)*

---

## Patterns Observed

<2-3 recurring themes across findings. Systemic insights, not individual bugs.>

---

## Recommendations

<3-5 actionable improvement recommendations. Broader guidance, not "fix bug X".
Each links back to specific findings.>

---

## Appendix: Files Analyzed

<Bullet list of all files included in the analysis>
```

**Save** to `$SESSION_DIR/04-report.md` AND display the full report to the user.

#### Phase 5: User Gate

```
Reflection complete. What next?

  [accept]     -- save and finish
  [deeper]     -- analyze a specific area in more depth
  [implement]  -- hand off top findings to /fw:implement
  [delegate]   -- assign specific findings to /fw:delegate
```

**Gate behavior:**
- **accept**: Print session path, done.
- **deeper**: Ask which area (file, module, or specific aspect). Re-run Phase 2 for that subset only. Update 02-analysis-raw.md, re-run Phase 3-4, re-display report. Repeat gate. **Max 2 deeper rounds** -- after 2, only accept/implement/delegate remain.
- **implement**: Extract all critical and high findings. Format as a feature description: "Fix the following quality issues in <scope>: ..." and instruct the user to run `/fw:implement <description>`. Print the pre-populated command.
- **delegate**: Ask which specific findings to delegate. Format as a task description and instruct the user to run `/fw:delegate using codex <task>`. Print the pre-populated command.

#### Error Handling

Following the pattern from `/Users/dali/Documents/GitHub/flywheel-plugin/commands/harden.md` lines 435-441:

- **dispatch.sh exits non-zero**: Show the error, offer to retry the aspect or skip it (remaining aspects continue)
- **Codex not available**: Fall back to claude sub-agents for standard/deep depth. If claude sub-agents also unavailable, Claude analyzes directly with a reduced-depth note.
- **No findings in an aspect**: Report a clean result for that aspect -- still include it in the report with "No issues found"
- **User cancels at any phase**: Save session state and print the session directory path
- **Scope resolves to 0 files**: Error with message: "No files found in the specified scope. Check the path and try again."

#### Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `FLYWHEEL_MAX_TIMEOUT` | `1800` | Max seconds per sub-agent call |
| `FLYWHEEL_CODEX_SANDBOX` | `workspace-write` | Codex sandbox mode |
| `FLYWHEEL_SHOW_THINKING` | `true` | Show Codex reasoning output |
| `FLYWHEEL_PROJECT` | `<git repo name>` | Override project name for session isolation |
| `FLYWHEEL_REFLECT_DIR` | `~/.flywheel/projects/<project>/reflect` | Where reflection session files are saved |

**Validation checklist:**
- [ ] YAML frontmatter has `description:` field
- [ ] Persona activation line references `fw-reflector`
- [ ] Step 0 creates session dir with the standard `$PROJECT_NAME` derivation
- [ ] All phases save to `$SESSION_DIR/0N-name.md`
- [ ] Dispatch calls use `"${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh"` (not direct CLI calls)
- [ ] Error handling section covers: dispatch failure, provider unavailable, empty scope, user cancel
- [ ] Environment variables section present
- [ ] User gate offers all 4 options: accept, deeper, implement, delegate
- [ ] "deeper" rounds capped at 2

---

### Task 3: Install and Verify Persona

**What:** Run install script to verify the new persona is picked up.

**Depends on:** Task 1

**Validation:**
- [ ] `scripts/install-personas.sh` copies `fw-reflector.md` to `~/.claude/agents/`
- [ ] No errors during install
- [ ] Persona file is readable at `~/.claude/agents/fw-reflector.md`

---

### Task 4: End-to-End Validation

**What:** Manual testing across all scope types and depth levels.

**Depends on:** Tasks 1, 2, 3

**Test matrix:**

| Test | Scope | Aspects | Expected Depth | Key Validation |
|------|-------|---------|----------------|----------------|
| T1 | Single file (`commands/harden.md`) | all | quick | No sub-agents, report generated, session saved |
| T2 | Module (`commands/`) | implementation, clean code | standard | Codex dispatched for each aspect, report synthesized |
| T3 | `staged` (with <5 staged files) | all | quick | Git diff parsed, files resolved, inline analysis |
| T4 | `project` | design patterns, test coverage | deep | Chunked dispatch, report aggregated |
| T5 | Args parsing: `/fw:reflect src/auth clean code patterns` | -- | -- | Aspects parsed from args, no prompt shown |
| T6 | No args: `/fw:reflect` | -- | -- | Both scope and aspect prompts displayed |
| T7 | User gate: deeper | -- | -- | Phase 2 re-runs on subset, report updated |
| T8 | User gate: implement | -- | -- | Pre-populated `/fw:implement` command printed |
| T9 | Codex unavailable | any | any | Graceful fallback to claude, reduced-depth note |
| T10 | Empty scope (nonexistent path) | any | -- | Error message, no crash |

---

## 5. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| **Aspect prompts produce inconsistent severity calibration** across different codex/claude instances | Medium | Medium | Synthesis phase (Phase 3) explicitly deduplicates and recalibrates. The `fw-reflector` persona instruction mandates honest severity. |
| **Large project scope hits dispatch timeout** (30 min default) | Medium | High | Chunking strategy limits each dispatch to ~10 files. Individual chunk timeouts are manageable. User can also set `FLYWHEEL_MAX_TIMEOUT`. |
| **Context file size cap** (dispatch.sh caps at 50KB per file) causes truncation on large files | Low | Medium | Phase 2 can split large files or summarize first. For quick depth, Claude reads directly without dispatch, avoiding the cap. |
| **"deeper" re-entry creates confusing report state** if user runs it twice | Low | Low | Capped at 2 rounds. Each round overwrites 02/03/04 files with updated versions. Previous versions are not preserved (session dir is already timestamped). |
| **Overlap with `/fw:review` causes user confusion** about which to use | Medium | Low | Command description, persona `avoid_if`, and report header all clarify: reflect = scope-agnostic narrative, review = PR-bound inline comments. CLAUDE.md can be updated to mention the distinction. |
| **Aspect keyword parsing misidentifies user intent** (e.g., file named "test.py" parsed as test aspect) | Low | Low | Aspect keywords are only extracted from args *after* the scope token is consumed. Scope detection runs first. |

---

## 6. Validation Strategy

### Acceptance Test

A successful `/fw:reflect` invocation must:
1. Create `$SESSION_DIR/` with 00-session.md, 01-scope.md, 02-analysis-raw.md, 03-synthesis.md, 04-report.md
2. Display the full report to the user
3. Present the user gate with all 4 options
4. Handle "accept" cleanly (print session path, done)
5. Handle "deeper" with re-analysis of a subset
6. Handle "implement" with a pre-populated command suggestion

### Test Coverage Plan

| Layer | What to Test | Method |
|-------|-------------|--------|
| Scope parsing | All 5 scope types resolve correctly | Manual: invoke with each scope type, verify 01-scope.md |
| Aspect parsing | Args-based and prompt-based aspect selection | Manual: test with args (`/fw:reflect src/ clean code`) and without |
| Depth classification | File count thresholds trigger correct depth | Manual: test with 1 file (quick), 10 files (standard), 25+ files (deep) |
| Dispatch routing | Codex called for standard/deep, not for quick | Manual: verify dispatch.sh invocation in session logs |
| Fallback behavior | Claude fallback when codex unavailable | Manual: test with codex unavailable (rename/disable codex CLI) |
| Report completeness | All sections present: summary, strengths, findings, patterns, recommendations, appendix | Manual: inspect 04-report.md for each test run |
| User gate: deeper | Re-analysis updates the report | Manual: select "deeper" at gate, verify report changes |
| User gate: implement | Pre-populated command is correct | Manual: verify printed command references critical/high findings |
| Error: empty scope | Graceful error message | Manual: invoke with nonexistent path |
| Session isolation | Different projects get different session dirs | Manual: run from two different repos, verify separate dirs |

---

## 7. Next Steps

1. **Implement Task 1**: Create `/Users/dali/Documents/GitHub/flywheel-plugin/agents/personas/fw-reflector.md`
2. **Implement Task 2**: Create `/Users/dali/Documents/GitHub/flywheel-plugin/commands/reflect.md`
3. **Run Task 3**: Execute `scripts/install-personas.sh` to install the new persona
4. **Run Task 4**: Execute the test matrix (T1-T10) against a real codebase
5. **Optional**: Update `/Users/dali/Documents/GitHub/flywheel-plugin/CLAUDE.md` to add `/fw:reflect` to the command overview, distinguishing it from `/fw:review` and `/fw:harden`
6. **Commit**: `feat: Add /fw:reflect command and fw-reflector persona for multi-dimensional quality reflection`
