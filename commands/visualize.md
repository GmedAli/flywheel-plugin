---
description: Generate mermaid diagrams to visualize code, changes, sessions, architectures, or concepts — picks the right diagram type from content signals (flowchart, sequence, class, state, ER, graph, mindmap, timeline, gitGraph)
---

# Visualize Workflow

> **Skill active:** `visualize` — picks diagram types from content signals, emits valid mermaid syntax, and self-skips when a diagram would add no value.

This command produces **one or more mermaid diagrams** that clarify a piece of code, a proposed solution, a set of changes, a system, or a concept. It auto-detects the source (similar to `/fw:summarize`), picks the appropriate diagram type(s), and renders them with short framing prose. **No code is ever modified — this command is strictly read-only.**

---

## Step 0: Parse Input & Detect Source

Parse the user's input after `/fw:visualize`:

| Input | Source type | What gets visualized |
|-------|-------------|----------------------|
| *(no arg)* | `auto` | Auto-detect: most recent session report → staged diff → last commit |
| `staged` / `diff` | `staged` | `git diff --cached` — what's about to be committed |
| `branch` | `branch` | `git diff <main>...HEAD` — the whole branch |
| `last` | `last_session` | Most recent Flywheel session in this project |
| `last <command>` | `last_session` | Latest session for that command (e.g. `last design`) |
| `commit <ref>` | `commit` | A specific commit |
| `commits <N>` | `commits` | Last N commits as a story |
| `<file_or_dir>` | `code` | A file or directory — visualize its structure / call graph |
| `architecture` / `system` | `architecture` | Project-wide architecture overview |
| `<concept>` | `concept` | A free-text topic or concept to visualize |

**Diagram type override** (optional trailing keyword):
- `flowchart` / `process` — force flowchart
- `sequence` / `interaction` — force sequence diagram
- `class` / `module` — force class diagram
- `state` / `lifecycle` — force state diagram
- `er` / `data` — force ER diagram
- `graph` / `dependencies` — force graph
- `mindmap` / `concept` — force mindmap
- `timeline` / `history` — force timeline
- `git` / `branches` — force gitGraph
- `architecture` / `c4` — force C4 diagram
- *(none)* — let the visualize skill pick

If the override is incompatible with the source (e.g. `sequence` requested for a single-file refactor), warn the user and pick the closest viable type.

Show the detection:
```
🎨 Source: <source type> — <path or description>
📐 Diagram: <auto-selected | user-overridden type>
```

**Create session directory:**
```bash
PROJECT_NAME="${FLYWHEEL_PROJECT:-$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")")}"
SESSION_DIR="$HOME/.flywheel/projects/$PROJECT_NAME/visualize/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$SESSION_DIR"
```

Save `$SESSION_DIR/00-session.md` with: source type, source path/ref, diagram preference, start timestamp, git branch.

---

## Phase 1: Gather Content 📥

> *Pull the raw material. No drawing yet.*

**Resolution by source type:**

- **staged**: `git diff --cached` plus `git diff --cached --stat`. If empty, stop with: *"No staged changes. Stage files with `git add` first, or specify a different source."*
- **branch**: `git diff main...HEAD` (fallback `master`, then `HEAD~1...HEAD`) plus `git log <base>..HEAD --oneline`
- **last_session**: Most recent session directory under `~/.flywheel/projects/<project>/`. Read the highest-numbered report file.
- **commit**: `git show <ref>` capped at ~3000 lines plus `git show <ref> --stat`
- **commits N**: `git log -<N>` and `git diff HEAD~<N>...HEAD --stat`
- **code** (file or directory):
  - File: read the file. Identify functions, classes, calls, imports.
  - Directory: list source files (excluding `node_modules`, `.git`, `dist`, `build`, `vendor`). Read up to 15 most relevant. Map imports / requires to build a dependency graph.
- **architecture**: Identify the project's main components — entry points, modules, services, data stores, external dependencies. Use `package.json` / `go.mod` / `pyproject.toml` / `Cargo.toml` / `requirements.txt` to detect the stack. List top-level directories and their purposes.
- **concept**: Use the free text as-is, plus any obvious codebase context (e.g. if the concept is "authorization", scan the codebase briefly for related files).
- **auto**: Try in order — most recent session → staged diff → last commit. Print which one was chosen.

Save the gathered context to `$SESSION_DIR/01-source.md` (cap 50KB; truncate with marker if larger).

Print:
```
✅ Phase 1 Complete — Content gathered
   Source: <description>
   Structural signals detected: <comma-separated — e.g. "control flow, multiple actors, state transitions">
```

---

## Phase 2: Select Diagram Type(s) 🎯

> *Apply the visualize skill's selection logic*

**Goal:** Pick one or more diagram types that match the dominant structural signals. Multiple diagrams are allowed when the content has distinct facets (cap **5 per output** for `/fw:visualize` — higher than the default skill cap of 3).

Apply the rules from `skills/visualize/SKILL.md`:

| Detected signal | Diagram chosen |
|-----------------|----------------|
| Branching control flow / decisions | Flowchart |
| Actors exchanging messages over time | Sequence diagram |
| Module / class structure | Class diagram |
| Lifecycle / state transitions | State diagram |
| Data entities with cardinality | ER diagram |
| Component dependency graph | Graph |
| Time-ordered events | Timeline / Gantt |
| Branch / commit history | Git graph |
| Hierarchical concept | Mindmap |
| System architecture across boundaries | C4 |

**If the user supplied an override**, use it (after compatibility check above).

**If no clear structural signal** is detected: tell the user, and offer:
```
⚠️ No clear structure detected for visualization.

  [pick]   — choose a diagram type explicitly
  [skip]   — abort (visualization wouldn't add value here)
  [text]   — fall back to /fw:summarize instead
```

Save the selection rationale to `$SESSION_DIR/02-selection.md` (which type, why, what each diagram will show).

Print:
```
✅ Phase 2 Complete — Diagram plan
   <N> diagrams: <type-1> · <type-2> · ...
```

---

## Phase 3: Generate Diagrams 🎨

> *Produce mermaid blocks following the skill's syntax rules*

For each selected diagram type, generate the mermaid block using the templates and quality checklist in `skills/visualize/SKILL.md`.

**Per-diagram generation steps:**
1. Identify the nodes/actors/entities from Phase 1 content
2. Identify the edges/messages/transitions
3. Group related nodes into subgraphs if the diagram has >8 nodes
4. Write the mermaid block using the matching template
5. Run the quality checklist — fix or downgrade if any check fails

**Cap per diagram: ~15 nodes.** If a diagram would exceed this, either:
- Split into two diagrams (e.g. one per subsystem), or
- Show the highest-level view only and note: *"<N> additional nodes elided for clarity"*

Save the generated diagrams to `$SESSION_DIR/03-diagrams.md`.

---

## Phase 4: Render Output 📋

You (Claude) write the final visualization document and display it to the user. Save to `$SESSION_DIR/04-visualization.md`.

```markdown
# Visualization: <SOURCE_DESCRIPTION>

> Generated by `/fw:visualize` · <DATE>
> Source: <source type> · Diagrams: <count>

---

## Overview

<2-3 sentences: what the source is, what aspect each diagram covers, and how to read them together.>

---

## <Diagram Heading 1>

> <one-sentence description of what this diagram shows and why this type was chosen>

```mermaid
<diagram body>
```

<Optional callouts (1-3): name non-obvious nodes/edges and explain what they represent.>

---

## <Diagram Heading 2>
*(repeat for each diagram)*

---

## Notes

<Only include if relevant: assumptions made, what was elided, what wasn't visualizable, related areas worth a follow-up diagram. Omit if there is nothing useful to add.>
```

Print:
```
✅ Visualization complete
   📄 Saved to: $SESSION_DIR/04-visualization.md
   Diagrams: <N>
```

---

## Phase 5: User Gate ⛔

Ask:
```
🎨 Visualization done. Anything else?

  [accept]   — keep as-is and finish
  [add]      — add another diagram (different angle or zoom level)
  [swap]     — change the diagram type for one of the existing diagrams
  [zoom]     — pick a node/subgraph and expand it into its own diagram
  [refine]   — describe what to adjust (labels, layout, scope)
  [export]   — copy diagrams into a project markdown file (docs/ or claudedocs/)
```

- **accept** → Print `Visualization saved to $SESSION_DIR/04-visualization.md` and stop.
- **add** → Ask which angle. Run Phase 2-3 for that angle only and append to the output. Repeat Phase 5.
- **swap** → Ask which diagram (by number) and which new type. Regenerate that one. Repeat Phase 5.
- **zoom** → Ask which node/area. Run Phase 1-3 with that node as the new scope. Append the resulting diagram. Repeat Phase 5.
- **refine** → Ask what to change. Edit the affected diagram. Max 3 refine rounds, then only `accept` and `export` are offered.
- **export** → Ask for a filename slug. Save the visualization to `docs/<slug>.md` if `docs/` exists, else `claudedocs/<slug>.md` (creating the directory if needed). Confirm the path. Stop.

---

## Examples

```bash
# Auto-detect — most recent session report or staged diff
/fw:visualize

# Visualize what's about to be committed
/fw:visualize staged

# Visualize the whole branch
/fw:visualize branch

# Visualize the project's architecture
/fw:visualize architecture

# Visualize the latest design proposal as flow + sequence
/fw:visualize last design

# Visualize a single file's call graph
/fw:visualize scripts/dispatch.sh

# Visualize a directory's module dependency graph
/fw:visualize commands/ graph

# Force a specific diagram type
/fw:visualize staged sequence
/fw:visualize architecture c4
/fw:visualize last debug state

# Visualize a concept with a mindmap
/fw:visualize how authentication flows through the app
/fw:visualize the release process timeline
```

---

## Error Handling

- **Source resolves to empty**: Stop with a clear message naming what was tried and how to specify a different source.
- **No structural signal in content**: Show the `pick / skip / text` options from Phase 2.
- **Mermaid syntax fails the quality checklist**: Downgrade to the simplest valid type and note: *"Original diagram type produced invalid syntax — falling back to <type>."*
- **Source larger than caps**: Truncate at the cap, visualize what was read, note truncation in the Notes section.
- **User cancels at any phase**: Save what's been written. Print `Session saved to $SESSION_DIR`.

---

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `FLYWHEEL_PROJECT` | `<git repo name>` | Override project name for session isolation |
| `FLYWHEEL_VISUALIZE_DIR` | `~/.flywheel/projects/<project>/visualize` | Where visualize session files are saved |
| `FLYWHEEL_VISUALIZE_MAX_DIAGRAMS` | `5` | Maximum diagrams per output (default cap for `/fw:visualize`) |
