---
description: Debug workflow — diagnose root cause, explain failing code, propose solutions (never modifies code)
---

# Debug Workflow

This command runs a structured 6-phase diagnostic workflow to identify root causes, explain issues, and propose solutions with impact depth. **No code is ever modified — this command is strictly read-only.**

---

## Step 0: Parse Input & Classify Severity

Parse the user's input:
- **Issue description**: the full text after `/fw:debug`
- If no description provided, ask: *"What issue would you like to debug? Paste an error message, describe unexpected behaviour, or point me to a file."*

**Collect additional context** if the user didn't provide it:
- Error messages, stack traces, or log output
- Which file(s) or area of the codebase is affected
- Expected vs actual behaviour

**Classify severity** from the description:

| Severity | Trigger signals | Effect |
|----------|----------------|--------|
| `low` | typo, style, config, lint, warning | Skip Phase 3 (Gemini cross-reference) |
| `medium` | runtime error, wrong output, missing data, regression | All phases |
| `critical` | crash, data loss, security, memory leak, deadlock, race condition | All phases + deeper analysis prompts |

Show the classification:
```
🐛 Issue: <description>
🔥 Severity: MEDIUM — running full diagnostic
```

**Create session directory:**
```bash
SESSION_DIR="$HOME/.flywheel/debug/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$SESSION_DIR"
```

Save `$SESSION_DIR/00-session.md` with:
- Issue description
- Severity
- Start timestamp
- Git branch (run `git branch --show-current`)
- Working directory
- Error output / stack trace (if provided)

---

## Phase 1: Reproduce & Observe 🔍

> *Claude scans the codebase to locate the problem area*

**Goal:** Find the failing code and gather surrounding context. No guessing — only observed facts.

You (Claude) perform:
1. **Locate the error site** — grep for error messages, function names, file references from the issue description
2. **Read the failing code** — view the relevant file(s) and note exact line ranges
3. **Trace data flow** — follow the call chain 1-2 levels up and down from the failure point
4. **Check recent changes** — run `git log --oneline -10 -- <affected_files>` to see recent commits touching the area
5. **Collect symptoms** — note what you observe: wrong values, missing calls, broken assumptions

Save findings to `$SESSION_DIR/01-observe.md`.

Print:
```
✅ Phase 1 Complete — Observation
   Failing area: <file:line_range>
   Symptoms: <brief list>
```

---

## Phase 2: Deep Analysis 🧠

> *Codex performs root-cause analysis with the full context from Phase 1*

**Goal:** Identify the root cause, not just the symptom.

Run Codex with diagnostic-specialist instructions:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh" "codex" "You are a diagnostic specialist. Analyse the following issue and identify the ROOT CAUSE — not just the symptom.

IMPORTANT: Do NOT modify any files. This is a read-only analysis.

ISSUE: <ISSUE_DESCRIPTION>

OBSERVED SYMPTOMS:
<contents of 01-observe.md>

FAILING CODE:
<the actual code block from Phase 1, with file path and line numbers>

Analyse:
1. What is the exact root cause? Trace the logical error step by step.
2. Why does this code fail? What assumption is broken?
3. What is the trigger? Under what conditions does this manifest?
4. Data flow: trace inputs → transformations → where correct behaviour diverges from actual
5. Are there related issues in the same area that could cause similar problems?

Be specific. Reference exact variable names, function calls, and line numbers. Do NOT suggest fixes yet — only diagnose." <AFFECTED_FILES>
```

Save output to `$SESSION_DIR/02-analysis.md`.

Print:
```
✅ Phase 2 Complete — Root Cause Analysis
   Root cause: <1-line summary>
```

---

## Phase 3: Cross-Reference 🌐

> *Gemini checks ecosystem knowledge for known issues and patterns*
> **Skipped for `low` severity**

**Goal:** Validate the diagnosis against ecosystem knowledge — is this a known library bug? A documented gotcha? A common anti-pattern?

Run Gemini:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh" "gemini" "Research whether the following issue is a known problem, documented gotcha, or common anti-pattern in the relevant ecosystem.

ISSUE: <ISSUE_DESCRIPTION>

ROOT CAUSE IDENTIFIED:
<1-paragraph summary from Phase 2>

TECHNOLOGY STACK:
<detected from Phase 1 — framework, language, key libraries>

Check:
1. Is this a known bug in the library/framework? Link to any issues or docs.
2. Is this a documented gotcha or migration pitfall?
3. Are there official recommended patterns to avoid this?
4. Has this been discussed in the community (Stack Overflow, GitHub Issues)?

Be concise. Only include findings that are directly relevant."
```

Save output to `$SESSION_DIR/03-crossref.md`.

Print:
```
✅ Phase 3 Complete — Cross-Reference
   Findings: <known issue / no matches / related pattern found>
```

---

## Phase 4: Diagnosis Report 📋

**Goal:** Synthesise all findings into a clear, actionable diagnosis report.

You (Claude) write the diagnosis using all context gathered. Save to `$SESSION_DIR/04-diagnosis.md` and display it to the user:

```markdown
# 🐛 Debug Diagnosis: <ISSUE_TITLE>

**Severity**: <LOW/MEDIUM/CRITICAL>
**Session**: <SESSION_DIR>
**Date**: <CURRENT_DATE>

---

## 🔍 Root Cause

<Concise explanation of WHY the issue occurs — 2-4 sentences max.
Focus on the broken assumption, the logical error, or the missing piece.>

---

## 📍 Failing Code

**File**: `<path/to/file>`
**Lines**: <start>-<end>

\```<language>
<the exact failing code block>
\```

<Arrow or annotation pointing to the specific line/expression that causes the issue>

---

## 💡 Explanation

<How the bug manifests in practice. Walk through the execution flow:
1. What triggers it (user action, input, timing)
2. What happens step by step
3. Where correct behaviour diverges from actual behaviour

Keep this concise — no more than a short paragraph per step.>

---

## 🛠️ Proposed Solution

**Impact Depth**: `<surface | local | module | system>`

| Depth | Meaning |
|-------|---------|
| `surface` | Config, styling, or environment change only |
| `local` | Single file change, isolated fix |
| `module` | Multiple files in the same module/feature |
| `system` | Cross-module or architectural change |

**What to change:**
<Describe the fix clearly — what code to modify, what to add/remove, and why.
Show a "before → after" conceptual diff if helpful.
Do NOT apply the changes — only describe them.>

**Why this works:**
<1-2 sentences explaining why this fix resolves the root cause.>

---

## ⚠️ Side Effects

<List anything else this fix might affect:
- Other callers of the modified function
- Tests that may need updating
- Performance implications
- Behavioural changes in edge cases

If no side effects: "None expected — the change is isolated.">

---

## 📚 References

<If Phase 3 found relevant ecosystem info, link to it here.
Otherwise omit this section.>
```

---

## Phase 5: User Decision Gate ⛔

Ask the user:
```
📋 Diagnosis complete. How would you like to proceed?

  [accept]   — acknowledge the diagnosis (no code changes)
  [deeper]   — run a more detailed analysis on a specific area
  [delegate] — hand off the fix to /fw:implement or /fw:delegate
```

- **accept** → Print "Debug session saved to `$SESSION_DIR`." and stop
- **deeper** → Ask which area to analyse further. Run Phase 2 again with a more targeted prompt focused on that area. Then regenerate Phase 4. Max 2 deeper rounds.
- **delegate** → Ask which command to use:
  - `/fw:implement <fix description>` — for structured fix workflow
  - `/fw:delegate using codex <fix description>` — for quick single-task fix

  Auto-populate the task description from the diagnosis report and hand off.

---

## Error Handling

- **Phase fails** (dispatch.sh exits non-zero): Show the error, offer to retry or skip the phase
- **Codex not available**: Fall back to Claude for Phase 2 with a note that analysis depth may be reduced
- **Gemini not available**: Skip Phase 3, note the gap in cross-reference
- **No error message provided**: Ask the user to reproduce the issue or describe the expected vs actual behaviour
- **Cannot locate failing code**: Ask the user to specify the file or function name

---

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `FLYWHEEL_MAX_TIMEOUT` | `1800` | Max seconds per agent call (30 min) |
| `FLYWHEEL_DEBUG_DIR` | `~/.flywheel/debug` | Where debug session files are saved |
