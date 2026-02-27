---
name: context7-research
description: >
  Auto-enriches research phases with official library documentation via Context7 MCP.
  Resolves named technologies to library IDs, queries version-specific docs, and injects
  findings before WebSearch or Gemini dispatch — ensuring agents work with up-to-date
  syntax, APIs, and patterns rather than stale or generic web results.
triggers: auto
scope: cross-cutting
consumers:
  - fw-researcher
  - commands/implement
  - commands/design
  - commands/migrate
  - commands/debug
  - commands/document
  - commands/harden
---

# Context7 Auto-Research Skill

## Purpose

Provide **official, version-specific library documentation** as the primary research source across all Flywheel workflows. Context7 MCP tools are available natively to Claude Code and its Task() sub-agents — no external scripts or dependencies required.

---

## Trigger Conditions

This skill activates automatically when **any** of the following are detected:

1. **Named technologies** in the task description or design brief (e.g., "React", "Express", "Redis", "Prisma")
2. **Version references** (e.g., "v19", "upgrade to 5.x", "migrate from 3 to 4")
3. **Framework-specific terms** (e.g., "hooks", "middleware", "ORM", "server components")
4. **Dependency manifest entries** — technologies found in `package.json`, `requirements.txt`, `go.mod`, `Cargo.toml`, etc. during codebase scan phases

---

## Technology Detection

Before invoking Context7, identify target technologies:

1. **Parse the task description** — extract library/framework names and version references
2. **Scan dependency manifests** — read `package.json` (or equivalent) for relevant packages
3. **Deduplicate** — merge task-description technologies with manifest entries
4. **Cap at 3 lookups per phase** — prioritise by relevance to the task; skip generic/obvious ones (e.g., don't look up "Node.js" itself unless the task is about Node-specific APIs)

---

## Context7 Workflow

For each detected technology (max 3 per phase):

### Step 1: Resolve Library ID

```
mcp__context7__resolve-library-id(
  libraryName: "<technology name>",
  query: "<task-specific query>"
)
```

- Select the result with the best match by name, reputation, and snippet count
- If no results found, skip this technology (non-blocking)

### Step 2: Query Documentation

```
mcp__context7__query-docs(
  libraryId: "<resolved ID from step 1>",
  query: "<command-type-specific query — see templates below>"
)
```

### Step 3: Format Findings

Structure the output as:

```markdown
## Context7 Documentation Findings

### <Library Name> (via Context7)
- **Library ID**: `<resolved ID>`
- **Relevant APIs/Patterns**: <key findings from query>
- **Version Notes**: <any version-specific information>
- **Gotchas**: <documented pitfalls or breaking changes>
```

### Step 4: Inject

- **Pattern A (Task path)**: Include findings in the sub-agent prompt as context
- **Pattern B (dispatch path)**: Prepend findings to the Gemini prompt as `OFFICIAL DOCUMENTATION CONTEXT`

---

## Integration Patterns

### Pattern A — Task Path (fw-researcher sub-agent)

When a command invokes `fw-researcher` via `Task()`, the researcher calls Context7 directly as its **first action** before WebSearch/WebFetch:

```
1. Detect technologies from task + codebase scan
2. For each technology (max 3):
   a. resolve-library-id → get Context7 ID
   b. query-docs → get relevant documentation
3. Use Context7 findings to inform what gaps remain
4. Fill gaps via WebSearch/WebFetch (primary sources)
5. Include Context7 section in output
```

Context7 findings inform what to search for next — if official docs already cover the topic comprehensively, WebSearch can focus on community experiences and edge cases instead of duplicating basic API documentation.

### Pattern B — Dispatch Path (Gemini via dispatch.sh)

When a command calls `dispatch.sh gemini` directly, Claude must enrich the prompt **before** dispatch (dispatch.sh agents cannot call MCP tools):

```
1. Detect technologies from task + codebase scan
2. For each technology (max 3):
   a. resolve-library-id → get Context7 ID
   b. query-docs → get relevant documentation
3. Prepend findings to the Gemini prompt:

   OFFICIAL DOCUMENTATION CONTEXT (via Context7):
   <formatted findings>

   ---
   <original Gemini prompt>
```

This gives Gemini access to official documentation it would otherwise need to search for (and might get wrong or miss).

---

## Query Templates by Command

Each command type uses a query template tailored to what it needs from documentation:

| Command | Query Template |
|---------|---------------|
| `/fw:implement` | "Best practices and API reference for implementing <FEATURE> with <library>" |
| `/fw:design` | "Architecture patterns and best practices for <DESIGN_BRIEF> with <library>" |
| `/fw:migrate` | "Migration guide for <library>. Breaking changes, deprecated APIs, and upgrade steps from <SOURCE_VERSION> to <TARGET_VERSION>" |
| `/fw:debug` | "Known issues, gotchas, and common errors with <library> related to <ROOT_CAUSE>" |
| `/fw:document` | "How <TOPIC> works in <library>. API reference, usage patterns, and configuration" |
| `/fw:harden` | "Security best practices, known vulnerabilities, and secure configuration for <package>" |

---

## Error Handling

**Every failure is non-blocking.** This skill is purely additive — workflows must never halt on enrichment failure.

| Failure | Behaviour |
|---------|-----------|
| `resolve-library-id` returns no results | Skip this technology, continue to next |
| `query-docs` returns empty or irrelevant results | Skip this technology, continue to next |
| Context7 MCP server unavailable | Skip all Context7 enrichment, log a note, continue workflow |
| Network timeout | Skip, continue — do not retry |
| All 3 lookups fail | Proceed without Context7 context; workflow continues as before |

When Context7 is skipped entirely, add a brief note to the session output:
```
ℹ️ Context7 enrichment skipped — <reason>. Proceeding with WebSearch/Gemini only.
```

---

## Token Budget

- **Max 3 lookups per phase** — most tasks involve 1-2 core technologies
- **Prefer specific queries** over broad ones — "React useEffect cleanup patterns" over "React documentation"
- **Trim verbose results** — extract only the relevant section from Context7 responses, not the full dump
- If Context7 returns >2000 tokens for a single query, summarise to the most relevant patterns and APIs

---

## Precedence Rules

1. **Context7 results take precedence** over generic web search results when both cover the same topic
2. **WebSearch fills gaps** that Context7 doesn't cover (community patterns, recent issues, real-world experiences)
3. **Gemini dispatch receives Context7 context** as authoritative input, not as suggestions to verify
4. When Context7 and WebSearch conflict, flag the discrepancy and prefer the Context7 (official) version
