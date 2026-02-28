---
name: sequential-thinking
description: >
  Activates structured iterative reasoning via the sequential-thinking MCP before
  complex analysis phases. Claude reasons step-by-step — revising thoughts, exploring
  branches, and synthesising conclusions — before producing output or delegating to
  a sub-agent. Automatically skipped for light/small/low complexity tasks.
triggers: auto
scope: cross-cutting
consumers:
  - fw-architect
  - commands/debug
  - commands/design
  - commands/implement
  - commands/harden
---

# Sequential Thinking Skill

## Purpose

Give Claude structured, iterative reasoning during analysis-heavy phases. Rather than jumping to conclusions, Claude builds a chain of connected thoughts — revising earlier ones when new evidence emerges, branching when multiple paths exist — before writing output or spawning a sub-agent.

This improves the quality of:
- Root-cause hypotheses in `/fw:debug`
- Architecture decisions in `/fw:design` and `/fw:implement`
- Threat modeling in `/fw:harden`
- ADRs produced by the `fw-architect` persona

**Prerequisite**: The `sequential-thinking` MCP server must be installed. Run `/fw:setup` for detection and installation guidance.

---

## Trigger Conditions

This skill activates automatically based on the complexity tier already detected in Step 0 of each command. No new detection logic is needed.

| Tier | Signal words / conditions | Activation |
|------|--------------------------|-----------|
| `light` / `small` / `low` | config, style, typo, rename, simple addition | ❌ Skip — fast path, no overhead |
| `standard` / `medium` | new feature, integration, refactor, runtime error | ✅ Activate |
| `deep` / `large` / `critical` | architecture, migration, crash, security, system redesign | ✅ Always activate |

For `/fw:harden` (which uses scope rather than severity): skip for `file` scope; activate for `module`, `project`, and `branch` scope.

---

## MCP Call Pattern

Invoke the tool in a reasoning loop:

```
mcp__sequential-thinking__sequentialthinking({
  thought: "<current reasoning step — one focused idea>",
  thoughtNumber: <N, starting at 1>,
  totalThoughts: <estimated count, adjustable as reasoning progresses>,
  nextThoughtNeeded: <true to continue, false when done>
})
```

**Optional — revise an earlier thought** when new evidence invalidates a prior conclusion:
```
  isRevision: true,
  revisesThought: <thought number being corrected>
```

**Optional — branch** when two paths warrant parallel exploration:
```
  branchFromThought: <thought number to branch from>,
  branchId: "<descriptive branch name>"
```

### Reasoning loop

1. Start with `thoughtNumber: 1` — frame the core question or constraint
2. Each subsequent thought builds on, refines, or challenges the previous
3. Adjust `totalThoughts` freely as understanding grows
4. Set `nextThoughtNeeded: false` on the final thought
5. **Hard cap: 8 thoughts per phase** — if reached, treat as complete

### Starter thought templates

| Context | Thought 1 starter |
|---------|------------------|
| `/fw:debug` Phase 2 | "What is the core failure, and at which layer of the call chain does it occur?" |
| `/fw:design` Phase 3 | "What are the fundamental design constraints and trade-offs for this goal?" |
| `/fw:implement` Phase 2 | "What are the key integration risks and dependencies for this feature?" |
| `/fw:harden` Phase 1 | "What are the primary attack surfaces and trust boundaries in this scope?" |
| `fw-architect` ADR | "What existing patterns in this codebase should govern this architecture decision?" |

---

## Integration Pattern

Sequential thinking runs **before** spawning sub-agents or writing structured output. It is a Claude-native MCP call — it cannot be used inside `dispatch.sh` sub-agents.

```
Command Phase (standard/medium/deep/large/critical)
    │
    ├─ [Sequential thinking skill]
    │   ├─ thought 1: frame the problem
    │   ├─ thought 2–N: explore, revise, branch as needed
    │   └─ nextThoughtNeeded: false → reasoning complete
    │
    ├─ Sequential Analysis Summary (2-4 sentences)
    │   └─ Injected into sub-agent context as SEQUENTIAL ANALYSIS:
    │
    └─ Spawn sub-agent / write output
         └─ Richer output built on structured prior reasoning
```

### Output: Sequential Analysis Summary

After the loop ends, synthesise the reasoning into a **Sequential Analysis Summary** — 2-4 sentences capturing:
- The core insight or problem framing
- Key unknowns or risks identified during reasoning
- The recommended focus for the next phase

Include this summary in the sub-agent task prompt under the heading `SEQUENTIAL ANALYSIS:`.

---

## Error Handling

Every failure is non-blocking. This skill is purely additive.

| Failure | Behaviour |
|---------|-----------|
| `mcp__sequential-thinking__sequentialthinking` unavailable | Skip the entire block silently; proceed to sub-agent or output |
| Tool returns error mid-loop | Stop loop; synthesise from thoughts completed so far |
| Hard cap of 8 thoughts reached | Treat as complete; synthesise immediately |
| Reasoning becomes circular | Detect repeated content → set `nextThoughtNeeded: false` |

When skipped entirely, no note is added to output. The phase proceeds as if the skill does not exist.

---

## Token Budget

- **Max 8 thoughts per phase** — most problems resolve in 4–6
- **One focused idea per thought** — not a wall of text
- The **Sequential Analysis Summary** (2-4 sentences) is what gets injected downstream, not the raw thought log
- Skip entirely if the task is unambiguous and the answer is already evident from the Phase 1 codebase scan

---

## Installation

The `sequential-thinking` MCP server must be installed. Run `/fw:setup` — it will detect availability and print the install command if missing:

```bash
claude mcp add sequential-thinking npx @modelcontextprotocol/server-sequential-thinking
```
