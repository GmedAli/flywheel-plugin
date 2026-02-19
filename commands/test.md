---
description: Proactive test generation — coverage analysis, gap detection, and automated test writing
---

# Test Generation Workflow

This command runs a structured 5-phase workflow to analyse test coverage gaps and generate missing tests. Claude orchestrates specialized agents at each phase. **Tests are generated to match your existing framework, conventions, and patterns.**

---

## Step 0: Parse Input & Detect Mode

Parse the user's input:
- **Mode specification**: the full text after `/fw:test`
- If no description provided, ask: *"What would you like to test? Options: 'branch' (changes on current branch), 'module src/auth/' (specific module), or 'sweep' (full project scan)"*

**Detect mode** from the input:

| Mode | Trigger | Effect |
|------|---------|--------|
| `branch` | "branch", "pr", "changes", "diff", or no argument with uncommitted changes | Only test new/changed code on current branch vs base |
| `module` | File path or directory provided | Full coverage analysis for that module |
| `sweep` | "sweep", "all", "project", "everything" | Project-wide coverage gap detection (may be slow) |

**Detect test framework** automatically:
- Check `package.json` for: jest, vitest, mocha, playwright, cypress, testing-library
- Check for: pytest, unittest (Python), go test (Go), cargo test (Rust), JUnit (Java)
- Check existing test files for import patterns and assertion styles
- Note the test directory convention (`tests/`, `__tests__/`, `*.test.*`, `*.spec.*`)

Show the classification:
```
🧪 Test Generation: <mode description>
🔧 Framework detected: <test framework + assertion library>
📁 Test convention: <test directory + naming pattern>
```

**Create session directory (per-project isolation):**
```bash
PROJECT_NAME="${FLYWHEEL_PROJECT:-$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")")}"
SESSION_DIR="$HOME/.flywheel/projects/$PROJECT_NAME/test/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$SESSION_DIR"
```

Save `$SESSION_DIR/00-session.md` with:
- Mode
- Test framework detected
- Test conventions
- Start timestamp
- Git branch (run `git branch --show-current`)
- Working directory

---

## Phase 1: Coverage Analysis 🔍

> *Codex analyses what's tested and what's not*

**Goal:** Build a map of tested vs untested code in the target scope.

### Mode-specific file selection

**Branch mode:**
```bash
# Get files changed on this branch vs base
git diff --name-only main...HEAD 2>/dev/null || git diff --name-only HEAD~10...HEAD
```
Only analyse source files (exclude tests, configs, docs, assets).

**Module mode:**
Use the specified path. List all source files in that directory.

**Sweep mode:**
List all source files in the project (exclude node_modules, vendor, build artifacts, etc.).

### Run coverage analysis

Run Codex:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh" "codex" "You are a test coverage analyst. Analyse the following source files and their existing tests to identify coverage gaps.

MODE: <MODE>
TEST FRAMEWORK: <DETECTED_FRAMEWORK>
TEST CONVENTIONS: <DETECTED_CONVENTIONS>

SOURCE FILES TO ANALYSE:
<list of source files with brief description of each>

EXISTING TEST FILES:
<list of test files that correspond to the source files>

For each source file, produce:

## Coverage Map

| Source File | Has Tests? | Test File | Functions Tested | Functions Untested | Branch Coverage Estimate |
|-------------|-----------|-----------|------------------|-------------------|------------------------|
| path/to/file.ts | ✅/❌ | path/to/test.ts | func1, func2 | func3, func4 | ~70% / Unknown |

## Untested Functions Detail

For each untested function, note:
| Function | File:Line | Complexity | Why It Matters |
|----------|-----------|-----------|----------------|
| funcName | path:42 | Low/Med/High | Handles user input / Core business logic / Error path |

Focus on what's MISSING, not what's already covered. Be thorough — a missed function means a coverage gap." <SOURCE_FILES> <TEST_FILES>
```

Save output to `$SESSION_DIR/01-coverage.md`.

Print:
```
✅ Phase 1 Complete — Coverage Analysis
   Files analysed: <N>
   Files with tests: <N>/<N>
   Untested functions: <N>
   Estimated coverage: ~<N>%
```

---

## Phase 2: Prioritise Test Gaps 📋

> *Claude ranks gaps by risk to focus effort where it matters most*

**Goal:** Not all untested code is equal. Prioritise by risk and impact.

You (Claude) review the coverage map and rank untested areas:

### Priority Matrix

| Priority | Criteria | Examples |
|----------|----------|---------|
| **P0 — Critical** | Public API, user input handling, auth/auth, data mutation, payment/billing | Login handler, API endpoint, database write |
| **P1 — High** | Business logic, data transformation, error handling, integration points | Price calculator, data parser, webhook handler |
| **P2 — Medium** | Internal utilities, helper functions, configuration loaders | String formatter, config reader, logger wrapper |
| **P3 — Low** | Pure presentation, static mappings, trivial getters/setters | Constants file, type definitions, simple wrappers |

Display the prioritised list:

```markdown
# 🧪 Test Gap Analysis

## P0 — Critical (must test)
| Function | Location | Why |
|----------|----------|-----|
| handleLogin | auth.ts:45 | Handles user credentials, auth flow |
| createOrder | orders.ts:89 | Mutates data, involves payment |

## P1 — High (should test)
| Function | Location | Why |
|----------|----------|-----|
| parseWebhook | webhooks.ts:12 | External input, error-prone |
| calculateTax | billing.ts:67 | Business logic, edge cases |

## P2 — Medium (nice to have)
...

## P3 — Low (defer)
...

**Recommended scope**: Generate tests for P0 + P1 (<N> functions, ~<N> test cases)
```

Save to `$SESSION_DIR/02-priorities.md`.

### User Gate

Ask:
```
📋 Test gaps prioritised. What would you like to generate?

  [all]      — generate tests for P0 + P1 + P2 (<N> functions)
  [critical] — generate tests for P0 + P1 only (<N> functions)
  [pick]     — let me choose specific functions to test
  [report]   — just save the analysis, don't generate tests
```

- **all** → Phase 3 with P0 + P1 + P2
- **critical** → Phase 3 with P0 + P1 only
- **pick** → Ask user to list specific functions, then Phase 3
- **report** → Print "Test analysis saved to `$SESSION_DIR`." and stop

---

## Phase 3: Generate Tests 🛠️

> *Codex writes tests matching your existing conventions*

**Goal:** Generate production-quality tests that fit seamlessly into the existing test suite.

### 3a — Gather test patterns (Claude)

Before generating, you (Claude) study 2-3 existing test files to extract:
- Import style and module resolution
- Test structure (describe/it, test(), class-based)
- Assertion style (expect, assert, should)
- Mocking patterns (jest.mock, vi.mock, unittest.mock, etc.)
- Setup/teardown patterns (beforeEach, setUp, fixtures)
- Naming conventions for test descriptions
- File naming pattern (*.test.ts, *.spec.ts, test_*.py, etc.)

Save patterns to `$SESSION_DIR/03-conventions.md`.

### 3b — Generate tests (Codex)

Run Codex in batches (group by source file, max 5 files per batch):

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh" "codex" "You are a test engineer. Write comprehensive tests for the following functions.

TEST FRAMEWORK: <DETECTED_FRAMEWORK>

EXISTING TEST CONVENTIONS (follow these EXACTLY):
<contents of 03-conventions.md>

FUNCTIONS TO TEST:
<for each function: name, file, line number, and the function body>

EXISTING TESTS (to avoid duplication):
<list of existing test descriptions for these files>

Requirements:
1. Match the EXACT style of existing tests — imports, structure, assertions, naming
2. For each function, write:
   - Happy path test(s) — normal expected inputs
   - Edge case tests — empty inputs, null/undefined, boundary values
   - Error path tests — invalid inputs, thrown exceptions, rejected promises
   - If the function has side effects, test those explicitly
3. Use proper mocking for external dependencies (APIs, databases, file system)
4. Each test description should clearly state WHAT is being tested and the EXPECTED outcome
5. Do NOT duplicate any existing tests
6. Place tests in the correct file following project conventions

Write the complete test file(s) — ready to run with no modifications." <SOURCE_FILES>
```

Save output to `$SESSION_DIR/03-tests-batch-<N>.md`.

Print after each batch:
```
✅ Batch <N>/<total> — Tests generated for <file_list>
   Tests written: <N>
   Functions covered: <N>
```

---

## Phase 4: Validate & Fix 🔄

> *Run the generated tests and fix failures — max 3 retry rounds*

**Goal:** Ensure all generated tests actually pass.

### 4a — Run tests

Execute the test suite (detect the correct command):
```bash
# Detect from package.json scripts, Makefile, etc.
# Examples:
# npm test
# npx jest --passWithNoTests
# npx vitest run
# pytest
# go test ./...
# cargo test
```

Capture output and parse results.

### 4b — Handle failures

If tests fail:

**Round 1-3:** Run Codex to fix failing tests:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh" "codex" "The following generated tests are failing. Fix them.

IMPORTANT: Fix the TESTS, not the source code. The source code is correct — the tests need to match actual behaviour.

FAILING TESTS:
<test names and error messages>

TEST CODE:
<the generated test code>

SOURCE CODE:
<the source functions being tested>

Fix the tests so they pass. Common issues:
- Wrong expected values (check actual function behaviour)
- Missing mocks or incorrect mock setup
- Async handling issues (missing await, wrong promise handling)
- Import path issues
- Setup/teardown missing" <TEST_FILES>
```

Re-run tests after each fix attempt.

**After 3 rounds:** If tests still fail, report which ones couldn't be fixed and move on.

Print:
```
✅ Phase 4 Complete — Test Validation
   Total tests: <N>
   Passing: <N> ✅
   Fixed after retry: <N> 🔄
   Still failing: <N> ❌ (manual review needed)
```

Save results to `$SESSION_DIR/04-validation.md`.

---

## Phase 5: Report ✅

**Goal:** Summarise what was generated and the coverage improvement.

You (Claude) produce the final report. Save to `$SESSION_DIR/05-report.md` and display:

```markdown
# ✅ Test Generation Complete

## Summary
<2-3 sentence description of what was generated>

## Coverage Improvement

| Metric | Before | After | Delta |
|--------|--------|-------|-------|
| Functions tested | <N>/<total> | <N>/<total> | +<N> |
| Estimated coverage | ~<N>% | ~<N>% | +<N>% |

## Tests Generated

| Source File | Test File | Tests Added | Status |
|-------------|-----------|-------------|--------|
| src/auth.ts | tests/auth.test.ts | 8 | ✅ All passing |
| src/orders.ts | tests/orders.test.ts | 12 | ✅ All passing |
| src/billing.ts | tests/billing.test.ts | 6 | ⚠️ 1 needs manual fix |

## Test Breakdown

| Category | Count |
|----------|-------|
| Happy path | <N> |
| Edge cases | <N> |
| Error paths | <N> |
| Integration | <N> |

## Remaining Gaps

<Functions that still need tests but were deferred (P3 or user-excluded):>
| Function | Location | Priority | Reason Deferred |
|----------|----------|----------|-----------------|
| ... | ... | P3 | Trivial getter |

## Tests Needing Manual Review

<Any tests that failed after 3 retry rounds — include the error for manual debugging:>
| Test | Error | Likely Cause |
|------|-------|-------------|
| ... | ... | ... |

## Suggested Next Steps
- Review any manually-flagged tests
- Run `/fw:harden` to add security-focused test cases
- Run `/fw:review` before merging
- Commit: `git add <test_files> && git commit -m "test: add coverage for <scope>"`
- Consider adding coverage thresholds to CI

## Session Files
All phase outputs saved to: <SESSION_DIR>
```

---

## Error Handling

- **Phase fails** (dispatch.sh exits non-zero): Show the error, offer to retry or skip the phase
- **Codex not available**: Fall back to Claude for Phases 1 and 3 with a note that test generation may be less precise
- **No test framework detected**: Ask the user what framework to use, or suggest one based on the stack
- **No existing tests to learn from**: Generate tests using framework defaults and best practices
- **All tests pass on first run**: Skip Phase 4 validation retries — report success
- **Source code has no functions** (e.g., config-only files): Report "nothing to test" for those files
- **User cancels at any phase**: Save session state and print the session directory path

---

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `FLYWHEEL_MAX_TIMEOUT` | `1800` | Max seconds per agent call (30 min) |
| `FLYWHEEL_CODEX_SANDBOX` | `workspace-write` | Codex sandbox mode |
| `FLYWHEEL_SHOW_THINKING` | `true` | Show Codex reasoning output |
| `FLYWHEEL_PROJECT` | `<git repo name>` | Override project name for session isolation |
| `FLYWHEEL_TEST_DIR` | `~/.flywheel/projects/<project>/test` | Where test session files are saved |
