---
description: Summarize proposed solutions or code changes in plain, simple language — translates technical reports, design docs, diffs, or commits into clear ELI5 explanations. Optionally enriches the summary with mermaid diagrams via the visualize skill.
---

# Summarize Workflow

> **Skill available:** `visualize` — activates on-demand to add mermaid diagrams when the source has clear structural signals (process flow, actor interactions, state transitions, dependencies). Auto-skips for flat content.

This command produces a **plain-English summary** of either a proposed solution (a design report, debug diagnosis, reflection, or any markdown plan) or actual changes made (staged diff, branch diff, recent commits, or a specific commit). The goal is clarity for a non-expert reader — no jargon, no hedging, no fluff. **No code is ever modified — this command is strictly read-only.**

---

## Step 0: Parse Input & Detect Source

Parse the user's input after `/fw:summarize`:

| Input | Source type | What gets summarized |
|-------|-------------|----------------------|
| *(no arg)* | `auto` | Auto-detect: most recent Flywheel session report if newer than HEAD; else staged diff; else last commit |
| `staged` / `diff` | `staged` | `git diff --cached` |
| `branch` | `branch` | `git diff <main>...HEAD` (fallback `master`, then `HEAD~1...HEAD`) |
| `last` | `last_session` | Most recent session in `~/.flywheel/projects/<project>/` (any command) |
| `last <command>` | `last_session` | Most recent session for that command (e.g. `last design`, `last debug`) |
| `commit <ref>` | `commit` | `git show <ref>` |
| `commits <N>` | `commits` | `git log -<N>` and `git diff HEAD~<N>...HEAD` |
| `<path>` | `file` | A markdown report or any text file path |
| free text | `text` | The text itself |

**Detect ambiguity** — if the input matches multiple categories, prefer the more specific one (file path beats free text; explicit `staged` beats auto).

If `auto` and nothing is detectable (no sessions, no staged changes, no commits), ask:
*"What should I summarize? Try `staged`, `branch`, `last`, `commit <ref>`, a path to a report, or paste the text directly."*

**Classify length** to control output size:

| Length | Trigger | Summary length |
|--------|---------|----------------|
| `tiny` | <50 lines of source / single commit / single file change | 2-3 sentences |
| `short` | 50-500 lines / small session report / staged with <10 files | 1 short paragraph |
| `medium` | 500-2000 lines / full session report / branch with <20 files | 3-5 bullet points + 1 paragraph |
| `long` | >2000 lines / multiple sessions / large branch | Sectioned summary (Overview / What changed / Why) |

The user can override with a trailing keyword: `tiny`, `short`, `medium`, `long`.

**Visualization mode** — detect from trailing keywords (independent of length):

| Keyword | Effect |
|---------|--------|
| `visualize` / `with diagrams` / `+diagrams` | Force the visualize skill to run (Phase 2.5) |
| `no diagrams` / `text only` | Skip the visualize skill even if signals are present |
| *(none)* | Auto — visualize skill self-evaluates the content's structural signals |

Show the detection:
```
📝 Source: <source type> — <path or description>
📏 Length: <classification> — producing <output style>
🎨 Visualize: <forced / auto / skipped>
```

**Create session directory:**
```bash
PROJECT_NAME="${FLYWHEEL_PROJECT:-$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")")}"
SESSION_DIR="$HOME/.flywheel/projects/$PROJECT_NAME/summarize/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$SESSION_DIR"
```

Save `$SESSION_DIR/00-session.md` with: source type, source path/ref, length classification, start timestamp, git branch.

---

## Phase 1: Gather Content 📥

> *Pull the raw material to summarize. No analysis yet.*

**Resolution by source type:**

- **staged**: `git diff --cached` and `git diff --cached --stat`. If empty, stop with: *"No staged changes. Stage files with `git add` first, or specify a different source."*
- **branch**: `git diff main...HEAD` and `git log main..HEAD --oneline`. Try `master` if `main` doesn't exist. Final fallback: `HEAD~1...HEAD`.
- **last_session**: Find the latest session directory matching the optional command filter:
  ```bash
  find "$HOME/.flywheel/projects/$PROJECT_NAME" -mindepth 2 -maxdepth 2 -type d \
    | sort -r | head -1
  ```
  Read the report files in that directory (prefer files matching `*-diagnosis.md`, `*-report.md`, `*-document.md`, `*-proposal.md`, or the highest-numbered file).
- **commit**: `git show <ref> --stat` and `git show <ref>` (capped at ~3000 lines).
- **commits N**: `git log -<N>` (full messages) and `git diff HEAD~<N>...HEAD --stat`.
- **file**: Read the file. If >2000 lines, read in chunks but cap total at 5000 lines and note truncation.
- **text**: Use the input as-is.
- **auto**: Try in order: most recent session newer than HEAD commit timestamp → staged diff → last commit. Print which one was chosen.

Save the gathered content to `$SESSION_DIR/01-source.md` (capped at 50KB; truncate with a `[truncated]` marker if larger).

Print:
```
✅ Phase 1 Complete — Content gathered
   Source: <description>
   Size: <N> lines / <M> KB
```

---

## Phase 2: Simplify ✍️

> *Translate technical content into plain language*

**Goal:** Produce a summary that a non-expert teammate could understand on first read. Avoid jargon. When a technical term is unavoidable, explain it inline in 4-6 words.

You (Claude) write the summary directly — no sub-agent dispatch needed. Apply these rules:

**Always do:**
- Lead with the *what* and *why* — never the *how*
- Use everyday verbs ("adds", "fixes", "moves", "renames") over jargon ("refactors", "introduces", "leverages")
- Spell out acronyms on first use unless universally known (HTTP, JSON, API are fine)
- For diffs/commits: state the user-visible effect, not the code mechanics
- For proposals: state the recommended action and the single biggest reason

**Never do:**
- Do not include file paths unless they are essential to understanding
- Do not list every changed function — group by feature or intent
- Do not hedge with "may", "might", "could potentially" if the source is definitive
- Do not pad with section headers if the content fits in 2-3 sentences
- Do not add any content not present in the source

### Output Templates by Length

**`tiny` (2-3 sentences):**
```
<One sentence: what this does or proposes>
<One sentence: why it matters or what problem it solves>
<Optional third sentence: any caveat or follow-up>
```

**`short` (1 paragraph):**
```
<3-5 sentences. Lead with the headline. Explain the change/proposal in plain terms.
End with the impact — who benefits, what improves, or what risk is reduced.>
```

**`medium` (bullets + paragraph):**
```
**In short:** <one-line headline anyone can understand>

**What this does:**
- <plain bullet 1>
- <plain bullet 2>
- <plain bullet 3>

**Why it matters:** <2-3 sentences on the impact and reasoning>
```

**`long` (sectioned):**
```
## In Plain Terms
<2-4 sentences — the headline as a friend would explain it>

## What Changed (or Is Proposed)
<grouped bullets — by feature, file, or theme. 5-10 bullets max.>

## Why
<the underlying reason — problem solved, capability added, risk addressed>

## What to Watch For
<only include if the source mentions risks, caveats, follow-ups, or open questions>
```

Save the summary to `$SESSION_DIR/02-summary.md` and display it to the user.

Print:
```
✅ Summary complete
   📄 Saved to: $SESSION_DIR/02-summary.md
```

---

## Phase 2.5: Visualize (optional) 🎨

> *Activate the `visualize` skill when the content has clear structural signals*

**Activation logic:**

| Visualize mode (from Step 0) | Behaviour |
|------------------------------|-----------|
| `forced` | Always run the skill — even for `tiny`/`short` summaries |
| `skipped` | Skip this phase entirely |
| `auto` | Run the skill only if Phase 1 content has at least one structural signal (per `skills/visualize/SKILL.md`). For `tiny` length, default to skip unless signal is unmistakable. |

When activated, follow `skills/visualize/SKILL.md`:
1. Detect dominant structural signals in the source content
2. Pick the most appropriate diagram type — **cap at 2 diagrams** for summaries (lower than `/fw:visualize`'s cap of 5, since summarize is prose-first)
3. Generate the mermaid block(s) using the templates and quality checklist
4. Append the diagram(s) to the summary under a `## At a glance` heading

**If the skill self-skips** (no clear structural signal), proceed silently — the summary stands on its own.

The appended visualization section format:

```markdown
---

## At a glance

> <one-sentence framing — what the diagram shows>

```mermaid
<diagram body>
```
```

Save the combined output (summary + diagrams) back to `$SESSION_DIR/02-summary.md`.

Print:
```
✅ Visualization added — <diagram type(s)>
```
*(or, if skipped:)*
```
ℹ️ Visualization skipped — no clear structural signal in source
```

---

## Phase 3: User Gate ⛔

Ask:
```
📋 Summary done. Anything else?

  [accept]    — keep as-is and finish
  [shorter]   — make it tighter
  [longer]    — add more detail
  [refine]    — tell me what to adjust
  [audience]  — re-tone for a specific reader (e.g. "for a PM", "for a junior dev")
  [visualize] — add (or replace) mermaid diagrams via the visualize skill
```

- **accept** → Print `Summary saved to $SESSION_DIR/02-summary.md` and stop.
- **shorter** → Drop one length tier (long→medium→short→tiny). Regenerate Phase 2. Repeat Phase 3.
- **longer** → Bump one length tier. Regenerate Phase 2. Repeat Phase 3.
- **refine** → Ask what to adjust. Rewrite Phase 2 incorporating the feedback. Max 3 refine rounds, then only `accept` is offered.
- **audience** → Ask the target reader (PM, junior dev, executive, customer). Re-tone Phase 2 for that audience without changing the facts. Repeat Phase 3.
- **visualize** → Force-run Phase 2.5 (or re-run with a different diagram type if diagrams are already present). Optionally accept a diagram-type hint (`flowchart`, `sequence`, `state`, etc.) — if none given, let the skill pick. For richer multi-diagram output, suggest: *"Use `/fw:visualize last summarize` for a fuller visualization with up to 5 diagrams."* Repeat Phase 3.

---

## Examples

```bash
# Auto-detect — uses latest session report or staged diff
/fw:summarize

# Summarize the most recent design/debug/reflect session
/fw:summarize last
/fw:summarize last design
/fw:summarize last debug

# Summarize what's about to be committed
/fw:summarize staged

# Summarize the whole branch in plain language
/fw:summarize branch

# Summarize a specific commit
/fw:summarize commit HEAD~2
/fw:summarize commit a3f1b2c

# Summarize the last 5 commits as one story
/fw:summarize commits 5

# Summarize a saved report or any markdown file
/fw:summarize claudedocs/auth-design.md
/fw:summarize ~/.flywheel/projects/myapp/design/20260504-110000/04-proposal.md

# Force a specific length
/fw:summarize staged tiny
/fw:summarize branch long

# Add mermaid diagrams alongside the prose summary
/fw:summarize staged visualize
/fw:summarize last design with diagrams
/fw:summarize branch long visualize

# Skip diagrams even if structure would warrant them
/fw:summarize branch no diagrams
```

---

## Error Handling

- **Source resolves to empty** (no staged changes, no sessions, no commits): Stop with a clear message naming what was tried and how to specify a different source.
- **File not found**: Suggest the closest match from the project tree.
- **Source larger than caps**: Truncate to the cap, summarize what was read, and note the truncation in the summary.
- **`last <command>` with no matching session**: List the available commands that have sessions and ask the user to pick.
- **User cancels at any phase**: Save what's been written and print `Session saved to $SESSION_DIR`.

---

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `FLYWHEEL_PROJECT` | `<git repo name>` | Override project name for session isolation |
| `FLYWHEEL_SUMMARIZE_DIR` | `~/.flywheel/projects/<project>/summarize` | Where summarize session files are saved |
