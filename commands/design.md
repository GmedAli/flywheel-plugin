---
description: Research-driven design workflow — analyze requirements, explore the codebase, research best practices, and produce a detailed plan of action (never modifies code)
---

# Design Workflow

> **Personas active:**
> - `fw-researcher` — ecosystem research phases (external best practices, library selection, known pitfalls)
> - `fw-architect` — technical planning phase (ADRs, file impact maps, risk register, approach recommendation)

This command runs a structured 6-phase research and design workflow. It produces a detailed plan-of-action document in the project root. **No code is ever modified — this command is strictly read-only and outputs only a plan.**

---

## Step 0: Parse Input & Classify Complexity

Parse the user's input:
- **Design brief**: the full text after `/fw:design`
- If no description provided, ask: *"What are you looking to build or change? Describe the feature, problem, or goal — even a rough idea is fine."*

**Clarify intent** with up to 3 focused follow-up questions if the brief is vague. Only ask what's needed to proceed — don't interrogate. Examples:

- "Who is the target user for this feature?"
- "Are there any hard constraints (tech stack, timeline, backward compatibility)?"
- "Should this integrate with an existing part of the system, or is it standalone?"

If the brief is already clear and specific, skip follow-ups and proceed.

**Classify complexity** from the description:

| Complexity | Trigger signals | Effect |
|------------|----------------|--------|
| `light` | config change, styling, rename, simple addition, one file | Skip Phase 2 (ecosystem research) and Phase 3 (deep analysis) |
| `standard` | new feature, integration, refactor, workflow change | All phases |
| `deep` | architecture, migration, system redesign, multi-service, security overhaul | All phases + expanded research scope + architecture decision records |

Show the classification:
```
📐 Design Brief: <description>
🧭 Complexity: STANDARD — running full design workflow
```

**Create session directory (per-project isolation):**
```bash
PROJECT_NAME="${FLYWHEEL_PROJECT:-$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")")}"
SESSION_DIR="$HOME/.flywheel/projects/$PROJECT_NAME/design/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$SESSION_DIR"
```

Save `$SESSION_DIR/00-session.md` with:
- Design brief (original + clarified)
- Complexity level
- Start timestamp
- Git branch (run `git branch --show-current`)
- Working directory

---

## Phase 1: Codebase Analysis 🔍

> *Claude scans the project to understand what exists and what's relevant*

**Goal:** Build a factual picture of the current system as it relates to the design brief. No speculation — only observed facts.

You (Claude) perform:

1. **Identify relevant areas** — grep for related terms, patterns, file names from the design brief
2. **Read key files** — view the most relevant files (aim for the minimum set that gives full context)
3. **Map existing patterns** — note conventions, architecture style, error handling, naming, test patterns
4. **Identify integration points** — APIs, shared utilities, services, data models that will be touched
5. **Detect constraints** — dependencies, version locks, existing tech debt, config limitations
6. **Note reusable components** — anything already in the codebase that could be leveraged

Save findings to `$SESSION_DIR/01-codebase-analysis.md`.

Print:
```
✅ Phase 1 Complete — Codebase Analysis
   Relevant files: <N> files across <M> directories
   Key patterns: <brief list>
   Constraints: <any notable ones>
```

---

## Phase 2: Ecosystem Research 🌐

> *Gemini researches best practices, packages, and known approaches*
> **Skipped for `light` complexity**

**Goal:** Gather external knowledge — best practices, existing solutions, packages, pitfalls.

**Context7 pre-enrichment** — before dispatching to Gemini, gather official documentation:

1. Identify technologies relevant to the design brief from Phase 1 findings (max 3)
2. For each, call `mcp__context7__resolve-library-id` then `mcp__context7__query-docs` with query: "Architecture patterns and best practices for <DESIGN_BRIEF> with <library>"
3. If Context7 returns results, prepend them to the Gemini prompt as `OFFICIAL DOCUMENTATION CONTEXT`
4. If Context7 fails or returns nothing, skip silently and proceed without enrichment

**Run Gemini:**
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh" "gemini" "OFFICIAL DOCUMENTATION CONTEXT (via Context7):
<Context7 findings, or omit this section if none>

---

Research best practices and existing solutions for the following design goal. Be specific and actionable — no generic advice.

DESIGN GOAL: <DESIGN_BRIEF>

CURRENT STACK:
<detected from Phase 1 — language, framework, key libraries, versions>

Research:
1. Recommended packages or libraries that solve this (or part of it). Include: name, GitHub stars/maintenance status, trade-offs.
2. Established implementation patterns for this type of feature in the current stack.
3. Known pitfalls, gotchas, and common mistakes.
4. Security considerations specific to this feature.
5. Performance implications and scalability concerns.
6. Real-world examples or case studies if available.

Prioritise solutions that fit the existing stack. Flag anything that would require a new dependency."
```

Save output to `$SESSION_DIR/02-ecosystem-research.md`.

Print:
```
✅ Phase 2 Complete — Ecosystem Research
   Key findings: <top 2-3 actionable insights>
   Packages identified: <list if any>
```

---

## Phase 3: Deep Analysis 🧠

> *Codex performs structured architectural analysis*
> **Skipped for `light` complexity**

**Goal:** Evaluate approaches, weigh trade-offs, and identify the best path forward.

Run Codex:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh" "codex" "You are a senior architect. Analyse the following design problem and evaluate implementation approaches. Do NOT write any code or modify files.

DESIGN GOAL: <DESIGN_BRIEF>

CODEBASE CONTEXT:
<contents of 01-codebase-analysis.md>

ECOSYSTEM RESEARCH:
<contents of 02-ecosystem-research.md>

Produce:
1. **Approach Options** — List 2-3 viable approaches. For each: brief description, pros, cons, effort estimate, risk level.
2. **Recommended Approach** — Pick one and explain why it's the best fit for THIS codebase (not generically).
3. **Architecture Decisions** — Key decisions that need to be made (with your recommendation for each).
4. **Dependency Assessment** — New dependencies needed (if any), with justification and alternatives.
5. **Risk Analysis** — What could go wrong? What's the rollback strategy?
6. **Open Questions** — Anything that needs user input before proceeding.

Be specific to this codebase. Reference actual file names, functions, and patterns you see in the context." <RELEVANT_FILES_FROM_PHASE_1>
```

Save output to `$SESSION_DIR/03-deep-analysis.md`.

Print:
```
✅ Phase 3 Complete — Deep Analysis
   Approaches evaluated: <N>
   Recommended: <brief name of recommended approach>
   Open questions: <count>
```

---

## Phase 4: Resolve Open Questions ❓

**Goal:** Close any gaps before writing the plan. Only ask what's genuinely blocking.

You (Claude) review findings from Phases 1-3 and identify unresolved decisions. Present them to the user:

```
🤔 A few decisions to make before I finalize the plan:

1. [Most impactful decision — e.g., "Should we add library X as a dependency or build a lightweight version?"]
2. [Second decision]
3. [Third, if needed]

(Answer each, or type "skip" to proceed with my recommendations)
```

**Rules:**
- Maximum 5 questions
- Only ask if the answer would change the plan
- For `light` complexity: skip this phase entirely (no ambiguity expected)
- If user says "skip": use the recommended option from Phase 3 for each decision

Save questions + answers to `$SESSION_DIR/04-decisions.md`.

---

## Phase 5: Write Plan of Action 📋

**Goal:** Produce the final design document — a complete, self-contained plan of action.

You (Claude) write the plan using all context gathered. Save to **both** `$SESSION_DIR/05-plan.md` and the project root as `DESIGN-PLAN.md`.

The document structure:

```markdown
# Design Plan: <FEATURE_NAME>

> Generated by `/fw:design` on <DATE>
> Session: `<SESSION_DIR>`
> Complexity: <LIGHT/STANDARD/DEEP>

---

## 1. Requirements

### What We're Building
<2-3 sentence summary of the feature/change in plain language>

### Success Criteria
- [ ] <Criterion 1 — specific and testable>
- [ ] <Criterion 2>
- [ ] <Criterion 3>

### Out of Scope
- <Explicitly excluded items>

### Constraints
- <Technical, timeline, or compatibility constraints>

---

## 2. Solution Overview

### Approach
<Brief explanation of the chosen approach and why it was selected over alternatives>

### Architecture Sketch
<High-level description of how components interact.
Use a simple ASCII diagram or bullet-point flow if helpful:>

```
[Component A] → [Component B] → [Component C]
       ↓
[Data Store]
```

### Key Decisions
| Decision | Choice | Rationale |
|----------|--------|-----------|
| <Decision 1> | <Choice> | <Why> |
| <Decision 2> | <Choice> | <Why> |

### New Dependencies
| Package | Purpose | Justification |
|---------|---------|---------------|
| <pkg> | <what it does> | <why we need it vs building it> |

*(If none: "No new dependencies required.")*

---

## 3. Impact Overview

### Files to Create
| File | Purpose |
|------|---------|
| `path/to/new/file` | <what it does> |

### Files to Modify
| File | Change Summary |
|------|---------------|
| `path/to/existing/file` | <what changes and why> |

### Files to Delete *(if any)*
| File | Reason |
|------|--------|
| `path/to/old/file` | <why it's being removed> |

---

## 4. Implementation Plan

### Task Breakdown

Each task is a self-contained unit of work. Tasks are ordered by dependency — later tasks may depend on earlier ones.

#### Task 1: <Title>
- **What**: <Clear description of what to do>
- **Files**: `file1.ts`, `file2.ts`
- **Depends on**: —
- **Validation**: <How to verify this task is done correctly>
  - [ ] <Specific check 1>
  - [ ] <Specific check 2>

#### Task 2: <Title>
- **What**: <Clear description>
- **Files**: `file3.ts`
- **Depends on**: Task 1
- **Validation**:
  - [ ] <Specific check>

#### Task 3: <Title>
...

*(Continue for all tasks. Typical range: 3-10 tasks depending on complexity.)*

### Suggested Task Order
```
Task 1 → Task 2 → Task 3
                 ↘ Task 4 (can run in parallel with Task 3)
                        → Task 5
```

---

## 5. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| <Risk 1> | Low/Med/High | Low/Med/High | <What to do about it> |
| <Risk 2> | ... | ... | ... |

---

## 6. Validation Strategy

### How to Know It's Done
<Describe the overall acceptance test — what should the system do when implementation is complete?>

### Test Coverage Plan
- **Unit tests**: <What to test at the unit level>
- **Integration tests**: <What integration points to verify>
- **Manual verification**: <Any manual checks needed>

---

## 7. Next Steps

- [ ] Review and approve this plan
- [ ] Run `/fw:implement <feature>` to execute
- [ ] Or delegate: `/fw:delegate using codex <task>` for individual tasks
```

Display the full document to the user.

Print:
```
✅ Phase 5 Complete — Plan of Action written
   📄 Saved to: DESIGN-PLAN.md (project root)
   📂 Session: <SESSION_DIR>
```

---

## Phase 6: User Review Gate ⛔

Ask the user:
```
📋 Design plan complete. How would you like to proceed?

  [approve]    — plan is good, save and finish
  [refine]     — tell me what to adjust (I'll update the plan)
  [deeper]     — research a specific area in more depth
  [implement]  — hand off directly to /fw:implement
```

- **approve** → Print "Design plan saved. Use `/fw:implement` when ready to build." and stop
- **refine** → Ask what to change, update the plan document, show the diff, repeat Phase 6. Max 3 rounds.
- **deeper** → Ask which area to investigate further. Run a targeted Phase 2 or 3 for that area, then update the plan. Repeat Phase 6.
- **implement** → Auto-populate `/fw:implement` with the design brief and reference the plan: "Implement the feature described in DESIGN-PLAN.md. Follow the task breakdown in Section 4."

---

## Error Handling

- **Phase fails** (dispatch.sh exits non-zero): Show the error, offer to retry or skip the phase
- **Codex not available**: Fall back to Claude for Phase 3 with a note that analysis depth may be reduced
- **Gemini not available**: Skip Phase 2, rely on Claude's knowledge + codebase analysis only. Note the gap.
- **User cancels at any phase**: Save session state and print the session directory path
- **DESIGN-PLAN.md already exists**: Ask whether to overwrite, rename (append timestamp), or cancel

---

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `FLYWHEEL_MAX_TIMEOUT` | `1800` | Max seconds per agent call (30 min) |
| `FLYWHEEL_PROJECT` | `<git repo name>` | Override project name for session isolation |
| `FLYWHEEL_DESIGN_DIR` | `~/.flywheel/projects/<project>/design` | Where design session files are saved |
