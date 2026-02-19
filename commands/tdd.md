---
description: Test-Driven Development — write tests first, implement to pass, refactor to clean
---

# TDD Workflow

This command runs a structured Red → Green → Refactor workflow for building features test-first. Claude orchestrates specialized agents through iterative cycles where **tests are always written before implementation code.** No production code exists until a failing test demands it.

---

## Step 0: Parse Input & Detect Scope

Parse the user's input:
- **Feature description**: the full text after `/fw:tdd`
- If no description provided, ask: *"What would you like to build using TDD? Describe the feature or behaviour."*

**Detect scope** from keywords in the description:

| Scope | Trigger words | Effect |
|-------|--------------|--------|
| `unit` | function, method, utility, helper, parser, validator | Single-function TDD cycles, fast iterations |
| `feature` | feature, endpoint, component, service, handler, flow | Multi-function TDD with integration tests |
| `module` | module, system, api, layer, pipeline | Full module TDD with unit + integration + contract tests |

Show the detected scope:
```
🔴 TDD: <description>
📐 Scope detected: FEATURE — multi-function cycles with integration tests
```

**Detect test framework** automatically:
- Check `package.json` for: jest, vitest, mocha, playwright, cypress, testing-library
- Check for: pytest, unittest (Python), go test (Go), cargo test (Rust), JUnit (Java)
- Check existing test files for import patterns and assertion styles
- Note the test directory convention (`tests/`, `__tests__/`, `*.test.*`, `*.spec.*`)

**Create session directory (per-project isolation):**
```bash
PROJECT_NAME="${FLYWHEEL_PROJECT:-$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")")}"
SESSION_DIR="$HOME/.flywheel/projects/$PROJECT_NAME/tdd/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$SESSION_DIR"
```

Save `$SESSION_DIR/00-session.md` with:
- Feature description
- Scope
- Test framework detected
- Test conventions (directory, naming, assertion style)
- Start timestamp
- Git branch (run `git branch --show-current`)
- Working directory

---

## Phase 1: Analyse & Design Test Cases 🔍

> *Claude + Codex decompose the feature into testable behaviours*

**Goal:** Break the feature into discrete, testable behaviours before writing any code. Define WHAT should happen, not HOW.

### 1a — Codebase Context (Claude, always runs)

You (Claude) scan the current project for:
- Existing patterns relevant to this feature (grep for related terms)
- Test conventions (read 2-3 existing test files for style)
- Files likely to be affected or extended
- Related interfaces, types, or contracts already in place

Summarise findings in `$SESSION_DIR/01-context.md`.

### 1b — Behaviour Decomposition (Codex)

Run Codex:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh" "codex" "You are a TDD expert. Decompose the following feature into a list of discrete, testable behaviours. Think in terms of WHAT the code should do, not HOW it does it.

FEATURE: <FEATURE_DESCRIPTION>

CODEBASE CONTEXT:
<contents of 01-context.md>

For each behaviour, specify:

## Test Plan

### Cycle 1: <Behaviour name — start with the simplest, most foundational case>
- **Test**: <What the test asserts in plain English>
- **Input**: <Example input>
- **Expected**: <Expected output or side effect>
- **Priority**: Core / Edge / Error

### Cycle 2: <Next simplest behaviour that builds on Cycle 1>
...

### Cycle N: <Most complex behaviour, built on all previous>
...

Rules:
1. Order by DEPENDENCY — each cycle should build on the previous
2. Start with the happy path of the simplest case
3. Include edge cases and error paths as separate cycles
4. Each cycle should be completable in one Red → Green → Refactor iteration
5. For FEATURE/MODULE scope, end with integration test cycles that verify the full flow

Also specify:
- **Files to create**: test file path(s) and source file path(s)
- **Interfaces first**: any types, interfaces, or contracts to define before Cycle 1"
```

Save output to `$SESSION_DIR/01-test-plan.md`.

### Phase 1 Summary

Display the test plan to the user:
```
✅ Phase 1 Complete — Test Plan
   Cycles planned: <N>
   Files to create: <list>
   Starting with: <Cycle 1 description>
```

### User Gate

Ask:
```
📋 Test plan ready. How would you like to proceed?

  [start]    — begin TDD cycles
  [modify]   — adjust the test plan
  [cancel]   — exit without changes
```

- **start** → continue to Phase 2
- **modify** → ask what to change, regenerate plan, repeat gate
- **cancel** → print "TDD session saved to `$SESSION_DIR`." and stop

---

## Phase 2: Define Interfaces & Contracts 📐

> *Codex creates the type definitions and interfaces before any implementation*
> **Skipped for `unit` scope**

**Goal:** Establish the contracts that tests will verify against. No logic — only shapes.

Run Codex:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh" "codex" "Based on the following test plan, create ONLY the type definitions, interfaces, and function signatures needed. Write ZERO implementation logic — every function body should throw or return a placeholder.

TEST PLAN:
<contents of 01-test-plan.md>

CODEBASE CONTEXT:
<contents of 01-context.md>

Requirements:
- Define all types and interfaces the tests will need
- Create source file(s) with function signatures that throw 'Not implemented' or equivalent
- Follow existing project conventions for types and file organisation
- Export everything the test files will import

This is the skeleton that tests will be written against."
```

Save output to `$SESSION_DIR/02-interfaces.md`.

Print:
```
✅ Phase 2 Complete — Interfaces Defined
   Types created: <list>
   Source skeleton: <file paths>
```

---

## Phase 3: TDD Cycles 🔴🟢🔵

> *The core loop — repeated for each cycle in the test plan*

**Goal:** For each planned cycle: write a failing test (Red), write minimal code to pass (Green), then clean up (Refactor).

### For each cycle (1 through N):

Print cycle header:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔄 Cycle <N>/<total>: <behaviour name>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

#### 🔴 RED — Write a Failing Test

Run Codex:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh" "codex" "You are in the RED phase of TDD. Write a FAILING test for the following behaviour. The test MUST fail because the implementation doesn't exist yet.

CYCLE: <cycle number> — <behaviour description>
TEST: <what the test should assert>
INPUT: <example input>
EXPECTED: <expected output>

EXISTING TESTS (do not duplicate):
<contents of test file so far, or 'None yet' for Cycle 1>

EXISTING SOURCE:
<contents of source file so far — interfaces/skeletons from Phase 2, or previous cycle implementations>

TEST FRAMEWORK: <DETECTED_FRAMEWORK>
TEST CONVENTIONS:
<conventions from 01-context.md>

Requirements:
- Write ONE test (or a small focused describe block) for this specific behaviour
- The test MUST import from the source file and call the actual function
- The test MUST fail right now (the function throws or returns wrong value)
- Use descriptive test names: 'should <expected behaviour> when <condition>'
- Follow existing test conventions EXACTLY
- Add the test to the existing test file — do NOT create a new file" <TEST_FILE> <SOURCE_FILE>
```

**Verify the test fails:**
Run the test suite and confirm it fails:
```bash
# Run only the specific test file for speed
# e.g., npx jest <test_file> --no-coverage
# e.g., npx vitest run <test_file>
# e.g., pytest <test_file> -x
```

Print:
```
🔴 RED — Test written and failing ✓
   Test: "<test description>"
   Error: <brief failure message>
```

If the test PASSES (shouldn't happen):
```
⚠️ Test already passes — the behaviour may already be implemented.
   [skip]     — move to next cycle
   [continue] — write the test anyway and proceed to Green
```

Save to `$SESSION_DIR/03-cycle-<N>-red.md`.

---

#### 🟢 GREEN — Write Minimal Code to Pass

Run Codex:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh" "codex" "You are in the GREEN phase of TDD. Write the MINIMUM code needed to make the failing test pass. Do NOT write more than what the test requires.

FAILING TEST:
<the test that was just written>

FAILURE MESSAGE:
<the actual error output from running the test>

EXISTING SOURCE:
<contents of source file so far>

CODEBASE CONTEXT:
<contents of 01-context.md>

Rules:
1. Write ONLY enough code to make this specific test pass
2. Do NOT anticipate future tests — solve only what's failing now
3. It's OK to hardcode values if the test allows it (future tests will force generalisation)
4. Do NOT break any previously passing tests
5. Follow existing code style and patterns" <SOURCE_FILE>
```

**Verify all tests pass:**
Run the full test file (not just the new test — ensure nothing regressed):
```bash
# Run the test file
```

Print:
```
🟢 GREEN — All tests passing ✓
   Tests: <N>/<N> passing
```

If tests still fail (max 2 fix attempts):
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh" "codex" "The test is still failing after the GREEN implementation. Fix the source code (NOT the test) to make it pass.

FAILING TEST:
<test code>

CURRENT SOURCE:
<source code>

ERROR:
<test failure output>

Fix the implementation. Do NOT modify the test." <SOURCE_FILE>
```

If still failing after 2 attempts, flag it:
```
⚠️ Cycle <N> GREEN phase stuck after 2 attempts.
   [retry]  — try once more with fresh approach
   [skip]   — mark as needs-manual-fix and continue
   [stop]   — pause TDD session here
```

Save to `$SESSION_DIR/03-cycle-<N>-green.md`.

---

#### 🔵 REFACTOR — Clean Up Without Changing Behaviour

> *Claude reviews, Codex refactors if needed*

You (Claude) review the current state of both test and source files for:
- **Duplication** — repeated logic that should be extracted
- **Naming** — unclear variable or function names
- **Structure** — code that's in the wrong place or poorly organised
- **Test clarity** — test descriptions that don't explain the behaviour
- **Patterns** — deviations from project conventions

If refactoring is needed:

Run Codex:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh" "codex" "You are in the REFACTOR phase of TDD. Improve the code quality WITHOUT changing any behaviour. All existing tests MUST still pass after refactoring.

CURRENT SOURCE:
<source file contents>

CURRENT TESTS:
<test file contents>

REFACTORING NEEDED:
<Claude's review notes — specific items to address>

Rules:
1. Do NOT change what the code does — only HOW it's written
2. All existing tests MUST pass after refactoring
3. Do NOT add new functionality
4. Extract duplicated code, improve names, simplify logic
5. Apply project conventions consistently" <SOURCE_FILE> <TEST_FILE>
```

**Verify all tests still pass** after refactoring.

If no refactoring needed:
```
🔵 REFACTOR — Code is clean, no changes needed ✓
```

If refactoring applied:
```
🔵 REFACTOR — Cleaned up ✓
   Changes: <brief list of what was refactored>
   Tests: <N>/<N> still passing
```

Save to `$SESSION_DIR/03-cycle-<N>-refactor.md`.

---

#### Cycle Complete

Print:
```
✅ Cycle <N>/<total> Complete — <behaviour name>
   🔴 Test written → 🟢 Implementation passing → 🔵 Refactored
   Total tests: <N> passing
```

**Proceed to next cycle** — loop back to 🔴 RED for the next behaviour in the test plan.

---

## Phase 4: Integration Verification 🔗

> *Run the full test suite and verify everything works together*
> **Skipped for `unit` scope**

**Goal:** After all cycles, verify that the individual pieces work together.

### 4a — Run full test suite

Run the project's complete test suite (not just the new test file):
```bash
# e.g., npm test, pytest, go test ./...
```

### 4b — Integration test (feature + module scope)

If the test plan included integration cycles, they should already be covered. If not, you (Claude) assess whether an integration test is needed:

- Does the feature involve multiple functions that interact?
- Are there cross-module calls?
- Is there I/O (API calls, database, file system)?

If yes, run one final Codex cycle to write an integration test:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh" "codex" "Write an integration test that verifies the full feature works end-to-end.

FEATURE: <FEATURE_DESCRIPTION>

ALL SOURCE CODE WRITTEN:
<source file contents>

ALL UNIT TESTS:
<test file contents>

TEST FRAMEWORK: <DETECTED_FRAMEWORK>

Write ONE integration test that exercises the complete flow from input to output. Mock external dependencies (APIs, databases) but test the full internal chain." <SOURCE_FILE> <TEST_FILE>
```

Run and verify.

Print:
```
✅ Phase 4 Complete — Integration Verified
   Unit tests: <N> passing
   Integration tests: <N> passing
   Total: <N>/<N> ✅
```

Save to `$SESSION_DIR/04-integration.md`.

---

## Phase 5: Report ✅

**Goal:** Summarise the TDD session with full traceability.

You (Claude) produce the final report. Save to `$SESSION_DIR/05-report.md` and display:

```markdown
# ✅ TDD Complete: <FEATURE_NAME>

## Summary
<2-3 sentence description of what was built using TDD>

## TDD Cycles

| Cycle | Behaviour | 🔴 Red | 🟢 Green | 🔵 Refactor | Status |
|-------|-----------|--------|----------|-------------|--------|
| 1 | <name> | ✅ | ✅ | ✅ | Complete |
| 2 | <name> | ✅ | ✅ | — (clean) | Complete |
| 3 | <name> | ✅ | ✅ | ✅ | Complete |
| ... | ... | ... | ... | ... | ... |

## Test Suite

| Metric | Count |
|--------|-------|
| Total tests written | <N> |
| Unit tests | <N> |
| Edge case tests | <N> |
| Error path tests | <N> |
| Integration tests | <N> |
| All passing | ✅ |

## Files Created / Modified

| File | Action | Purpose |
|------|--------|---------|
| src/feature.ts | CREATED | Feature implementation |
| tests/feature.test.ts | CREATED | Test suite |
| src/types.ts | MODIFIED | Added interfaces |

## Code Quality

- **Test-to-code ratio**: <N> tests per function
- **Refactoring rounds**: <N>/<total_cycles> cycles needed cleanup
- **Green attempts**: Average <N> attempts per cycle (1.0 = perfect)
- **Stuck cycles**: <N> (required manual intervention)

## Design Decisions Made During TDD

<List any design decisions that emerged from the TDD process:
- "Extracted a validator because Cycles 2 and 4 tested similar input rules"
- "Changed return type from string to Result<string, Error> after Cycle 3 error tests"
- These are valuable — they show how TDD shaped the design>

## Suggested Next Steps
- Run `/fw:harden` to check for security issues in the new code
- Run `/fw:review` before merging
- Run `/fw:test sweep` to check coverage across the broader codebase
- Commit: `git add <files> && git commit -m "feat: <feature> (TDD)"`

## Session Files
All phase outputs saved to: <SESSION_DIR>
```

---

## Error Handling

- **Phase fails** (dispatch.sh exits non-zero): Show the error, offer to retry or skip the phase
- **Codex not available**: Fall back to Claude for all Codex phases with a note that code generation may be less precise
- **Test framework not detected**: Ask the user what framework to use, or suggest one based on the stack
- **No existing tests to learn conventions from**: Use framework defaults and best practices
- **Cycle stuck in GREEN** (test won't pass after 2 retries): Offer retry / skip / stop
- **Refactoring breaks tests**: Revert the refactor and mark the cycle as clean-enough
- **User cancels mid-cycle**: Save session state including which cycles are complete — session is resumable
- **All cycles complete but integration fails**: Run a targeted debug cycle on the integration test failure

---

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `FLYWHEEL_MAX_TIMEOUT` | `1800` | Max seconds per agent call (30 min) |
| `FLYWHEEL_CODEX_SANDBOX` | `workspace-write` | Codex sandbox mode |
| `FLYWHEEL_SHOW_THINKING` | `true` | Show Codex reasoning output |
| `FLYWHEEL_PROJECT` | `<git repo name>` | Override project name for session isolation |
| `FLYWHEEL_TDD_DIR` | `~/.flywheel/projects/<project>/tdd` | Where TDD session files are saved |
