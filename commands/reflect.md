---
description: Multi-dimensional quality reflection — scope-agnostic analysis with selectable aspects, severity-sorted findings, strengths, and human-readable narrative report
---

# Reflect Workflow

> **Persona active:** `fw-reflector` — quality reflection specialist. Synthesizes multi-dimensional analysis findings into a narrative report. Balances strengths with concerns. Produces human-readable output, not inline PR comments.

This command runs a structured 5-phase quality reflection over any user-defined scope. Claude orchestrates analysis per selected aspect, synthesizes findings, and produces a narrative report sorted by severity. **No code is ever modified — this command is strictly read-only.**

---

## Step 0: Parse Input & Configure

Parse the user's input:
- **Scope specification**: file path, directory, `staged`, `branch`, `project`, or `all`
- **Aspect keywords** (optional): detected from the remaining args

If no scope is provided, ask:
*"What would you like to reflect on? Examples: `src/auth/`, `staged`, `the whole project`, or a specific file like `commands/debug.md`"*

**Detect scope type:**

| Scope | Detection | Files resolved |
|-------|-----------|----------------|
| `file` | Single file path | That file only |
| `module` | Directory path or module name | All source files in that directory |
| `project` | "project", "all", "everything", or no path | Full codebase (excluding build artifacts) |
| `staged` | "staged", "diff", or `git diff --cached` has content | Output of `git diff --cached --name-only` |
| `branch` | Branch name or "current branch" | Output of `git diff main...HEAD --name-only` (fallback: `master`) |

**Detect aspects from remaining args** — recognized keywords:
- `implementation` / `quality` / `logic` / `errors` → aspect 1
- `clean` / `readability` / `naming` / `dry` / `solid` → aspect 2
- `design` / `patterns` / `architecture` / `coupling` → aspect 3
- `test` / `coverage` / `testing` → aspect 4
- `all` → all four aspects

If no aspects are detected in args, present the selection prompt:
```
Which aspects would you like to analyze? (enter numbers, e.g. "1 3" or "all")

  1. Implementation quality — logic, error handling, async patterns, edge cases
  2. Clean code — naming, readability, DRY, SOLID, complexity
  3. Design patterns — architectural alignment, pattern consistency, coupling
  4. Test coverage — what's tested vs what's not, coverage gaps
```

Wait for the user's selection before continuing.

**Classify depth** based on files in scope (you'll refine this in Phase 1 once the exact count is known):

| Depth | Trigger | Analysis strategy |
|-------|---------|-------------------|
| `quick` | Single file or staged with <5 files | Claude reads and analyzes directly — no sub-agents |
| `standard` | Module/directory or staged with 5–20 files | Claude + targeted codex dispatch per aspect |
| `deep` | Project-wide or >20 files | Codex per analysis chunk (~10 files each); fallback to claude sub-agents |

Show the configuration:
```
🔍 Reflection: <scope description>
📐 Scope: <type> — <path or description>
🎯 Aspects: <selected aspect names>
```

**Create session directory:**
```bash
PROJECT_NAME="${FLYWHEEL_PROJECT:-$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")")}"
SESSION_DIR="$HOME/.flywheel/projects/$PROJECT_NAME/reflect/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$SESSION_DIR"
```

Save `$SESSION_DIR/00-session.md` with: scope description, aspects selected, start timestamp, git branch (`git branch --show-current`), working directory.

---

## Phase 1: Scope Resolution 🗂️

> *Claude resolves the exact list of files to analyze*

**Goal:** Produce a definitive file list for the selected scope. Group files by directory/domain.

**Resolution by scope type:**

- **file**: Verify the file exists. Use as-is.
- **module**: List all source files in the directory. Exclude `node_modules`, `.git`, `dist`, `build`, `vendor`, `__pycache__`, `*.lock`, `*.log`.
- **project**: Full project file listing. Same exclusions as module, applied recursively.
- **staged**: Run `git diff --cached --name-only`. If the output is empty, inform the user: *"No staged changes found. Stage some files with `git add` first, or specify a different scope."*
- **branch**: Run `git diff main...HEAD --name-only`. If `main` doesn't exist, try `master`. If neither, use `git diff HEAD~1...HEAD --name-only` and note the fallback.

**Group files** by top-level directory or domain (e.g., `commands/`, `agents/`, `scripts/`). This grouping is used for chunked dispatch in deep depth.

**Finalize depth** based on the actual file count:
- <5 files → `quick`
- 5–20 files → `standard`
- >20 files → `deep`

Save file list and groupings to `$SESSION_DIR/01-scope.md`.

Print:
```
✅ Phase 1 Complete — Scope resolved
   Files in scope: <N>
   Groups: <list>
   Depth: <quick / standard / deep>
```

---

## Phase 2: Analysis 🔍

> *Per-aspect analysis passes, dispatched at the appropriate depth*

**Goal:** Run each selected aspect as a focused analysis pass over the files in scope. Collect raw findings with evidence.

### Aspect Prompts

Use the following prompt for each selected aspect. Substitute `<ASPECT_PROMPT>` in the dispatch calls below.

---

**Aspect 1 — Implementation Quality:**
```
Analyze implementation quality in the following code. Focus on:
- Logic correctness (wrong conditions, off-by-one, inverted checks)
- Error handling (uncaught exceptions, empty catch blocks, silent failures)
- Async patterns (missing await, unhandled promises, race conditions)
- Edge cases (null/undefined guards, empty inputs, boundary values)
- Complexity (overly complex functions, hard-to-follow control flow)

For each finding: state the issue, the specific location (file:line), severity (critical/high/mid/low), and what the correct behaviour should be.
Also note 2-3 specific implementation strengths you observe — be concrete (name files and functions).
```

---

**Aspect 2 — Clean Code:**
```
Analyze code quality and readability in the following code. Focus on:
- Naming clarity (variables, functions, classes that misrepresent their purpose)
- DRY violations (duplicated logic that should be abstracted)
- SOLID violations (single responsibility, open/closed, etc.)
- Cognitive complexity (functions doing too many things, deep nesting)
- Magic numbers/strings (hardcoded values without named constants)
- Comment quality (missing explanations for non-obvious logic, outdated comments)

For each finding: state the issue, specific location (file:line), severity (critical/high/mid/low), and a brief suggestion for improvement.
Also note 2-3 specific clean code strengths you observe — be concrete (name files and functions).
```

---

**Aspect 3 — Design Patterns:**
```
Analyze architectural alignment and design pattern usage in the following code. Focus on:
- Pattern consistency (is there a clear architectural style? does the code follow it?)
- Coupling and cohesion (tight coupling, inappropriate dependencies, god objects)
- Separation of concerns (business logic mixed with I/O, presentation logic, etc.)
- Abstraction levels (leaky abstractions, missing abstractions, wrong layer placement)
- Convention adherence (naming, file structure, module organization)

For each finding: state the issue, specific location (file:line if applicable), severity (critical/high/mid/low), and which pattern or principle would address it.
Also note 2-3 specific architectural strengths you observe — be concrete.
```

---

**Aspect 4 — Test Coverage:**
```
Analyze test coverage gaps in the following code. Focus on:
- Critical paths with no tests (business logic, auth flows, data mutations)
- Edge cases missing test coverage (error paths, empty inputs, boundary values)
- Test quality (tests that test implementation details instead of observable behaviour)
- Brittleness (tests relying on internal state, timing, or uncontrolled external services)
- Coverage distribution (over-tested trivial code vs under-tested complex logic)

For each finding: state what is untested or poorly tested, the risk if it breaks undetected, severity (critical/high/mid/low), and what test(s) would provide meaningful coverage.
Also note 2-3 specific testing strengths you observe — be concrete.
```

---

### Dispatch Strategy by Depth

**Quick (Claude direct):**
- Read all files in scope (parallel Read calls)
- Run each selected aspect prompt against the file contents inline
- No dispatch.sh calls

**Standard (Claude + codex per aspect):**
- For each selected aspect, dispatch to codex:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh" "codex" "<ASPECT_PROMPT>

FILES IN SCOPE:
<file list from 01-scope.md>

PROJECT CONTEXT:
<1-2 sentences about the project type and conventions detected in Phase 1>" \
  <up to 10 context files from scope>
```
- If codex is unavailable, Claude performs the analysis directly with a note: `⚠️ Codex unavailable — analyzing directly (reduced depth)`

**Deep (codex per chunk per aspect):**
- For each selected aspect, iterate over file groups from Phase 1:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh" "codex" "<ASPECT_PROMPT>

CHUNK: <group name> (<N> files)

PROJECT CONTEXT:
<1-2 sentences about the project>" \
  <files in this chunk>
```
- Collect all chunk outputs and merge them per aspect
- If codex unavailable, fall back to claude:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh" "claude" "<ASPECT_PROMPT> ..."
```
- If both unavailable, Claude analyzes directly with a note: `⚠️ Sub-agents unavailable — analyzing directly (reduced depth for large scope)`

**Collect** all raw findings. Save to `$SESSION_DIR/02-analysis-raw.md` (one section per aspect).

Print per aspect as it completes:
```
  ✅ <Aspect name> — <N> findings (critical: <N>, high: <N>, mid: <N>, low: <N>) · <N> strengths noted
```

---

## Phase 3: Synthesis 🧠

> *`fw-reflector` persona aggregates, deduplicates, and identifies patterns*

**Goal:** Transform raw per-aspect findings into a coherent, prioritized quality picture.

**Activate `fw-reflector` persona** to perform the synthesis:

```
Task(fw-reflector): Synthesize the following raw quality analysis findings into a reflection report.

RAW FINDINGS:
<contents of 02-analysis-raw.md>

SCOPE: <scope description>
ASPECTS ANALYZED: <list>
FILES ANALYZED: <N>

Produce:
1. Deduplicated finding list — merge any findings that describe the same issue across aspects
2. All findings sorted into severity buckets: critical / high / mid / low
3. Top 3-5 concrete strengths (specific files/functions/patterns — no generic praise)
4. 2-3 systemic patterns observed across the findings
5. 3-5 actionable recommendations that address systemic issues (not individual bugs)
```

**Fallback — if fw-reflector persona not installed**, Claude performs the synthesis directly using the same instructions.

Save synthesis to `$SESSION_DIR/03-synthesis.md`.

Print:
```
✅ Phase 3 Complete — Synthesis
   Total findings: <N> (🔴 <N> · 🟠 <N> · 🟡 <N> · 🟢 <N>)
   Strengths: <N> · Patterns: <N>
```

---

## Phase 4: Report Generation 📋

**Goal:** Write the final human-readable reflection report.

You (Claude, as `fw-reflector`) write the report using the synthesis from Phase 3. Save to **both** `$SESSION_DIR/04-report.md` and display it in full to the user:

```markdown
# Reflection Report: <SCOPE>

> Generated by `/fw:reflect` · <DATE>
> Aspects: <selected aspects> · Depth: <quick/standard/deep>
> Files analyzed: <N>

---

## Summary

<3-4 sentences. The overall quality picture — honest and specific.
Name the single biggest strength and the single biggest concern.>

---

## Strengths 💪

- **<Strength 1>**: <concrete evidence — file/function/pattern>
- **<Strength 2>**: ...
- **<Strength 3>**: ...

---

## Findings

### 🔴 Critical
**<Finding title>**
<1-2 sentences: what the issue is, where it is (file:line if available), why it matters>

### 🟠 High
**<Finding title>**
<Same format>

### 🟡 Mid
**<Finding title>**
<Same format>

### 🟢 Low
**<Finding title>**
<Same format>

*(Empty severity buckets are omitted.)*

---

## Patterns Observed

- **<Pattern 1>**: <systemic theme — not a summary of a single finding>
- **<Pattern 2>**: ...

---

## Recommendations

1. **<Recommendation title>**: <actionable guidance. References specific findings.>
2. ...

---

## Appendix: Files Analyzed

<Bullet list of all files in scope>
```

Print:
```
✅ Phase 4 Complete — Report written
   📄 Saved to: $SESSION_DIR/04-report.md
```

---

## Phase 5: User Gate ⛔

Ask:
```
📋 Reflection complete. What next?

  [accept]     — save and finish
  [deeper]     — analyze a specific area in more depth
  [implement]  — hand off top findings to /fw:implement
  [delegate]   — assign specific findings to /fw:delegate
```

**Gate behavior:**

- **accept** → Print `Reflection session saved to $SESSION_DIR` and stop.

- **deeper** → Ask: *"Which area or aspect would you like to go deeper on? (e.g. `src/auth/`, `test coverage only`, `the error handling pattern`)"*
  - Re-run Phase 2 for the specified subset only (override scope and/or aspects as indicated)
  - Re-run Phase 3–4, overwrite `02-analysis-raw.md`, `03-synthesis.md`, `04-report.md`
  - Display the updated report
  - Repeat Phase 5
  - **Max 2 deeper rounds** — after the second round, only `accept`, `implement`, and `delegate` are offered

- **implement** → Extract all critical and high findings. Print the pre-populated command:
  ```
  Run: /fw:implement Fix the following quality issues in <scope>:
  <numbered list of critical and high findings with file locations>
  ```

- **delegate** → Ask which findings to delegate. Print the pre-populated command:
  ```
  Run: /fw:delegate using codex Fix <finding title> in <file:line>
  ```

---

## Error Handling

- **dispatch.sh exits non-zero**: Show the error. Offer to retry the aspect or skip it — remaining aspects continue unaffected.
- **Codex unavailable**: Fall back to claude sub-agents for standard/deep depth with a note: `⚠️ Codex unavailable — falling back to claude sub-agents`. If claude sub-agents also unavailable, Claude analyzes directly.
- **No findings for an aspect**: Include the aspect in the report with: *"No issues found."* — still valid output.
- **Scope resolves to 0 files**: Error with: *"No files found in the specified scope. Check the path and try again."* Save session and stop.
- **Staged scope is empty**: Inform the user: *"No staged changes found. Use `git add` to stage files, or specify a different scope."*
- **User cancels at any phase**: Save all session files written so far. Print: `Session saved to $SESSION_DIR`

---

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `FLYWHEEL_MAX_TIMEOUT` | `1800` | Max seconds per sub-agent call |
| `FLYWHEEL_CODEX_SANDBOX` | `workspace-write` | Codex sandbox mode |
| `FLYWHEEL_SHOW_THINKING` | `true` | Show Codex reasoning output |
| `FLYWHEEL_PROJECT` | `<git repo name>` | Override project name for session isolation |
| `FLYWHEEL_REFLECT_DIR` | `~/.flywheel/projects/<project>/reflect` | Where reflection session files are saved |
