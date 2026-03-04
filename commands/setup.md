---
description: Setup and validate provider integrations
---

# Flywheel Setup

This command validates all AI provider integrations and configures the plugin for use.

## Step 1: Bootstrap Configuration

1.  **Create Global Config Directory**:
    *   Run: `mkdir -p ~/.flywheel/projects`

2.  **Create Current Project Directory**:
    *   Detect project name:
        ```bash
        PROJECT_NAME="${FLYWHEEL_PROJECT:-$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")")}"
        mkdir -p "$HOME/.flywheel/projects/$PROJECT_NAME/results"
        ```
    *   **Message**: "Project directory created: `~/.flywheel/projects/<PROJECT_NAME>/`"

3.  **Grant Claude Code Permissions for Project Directory**:
    *   Run the permissions helper so that `Write`, `Edit`, and `Bash` operations targeting the project directory are auto-approved without user prompts:
        ```bash
        "${CLAUDE_PLUGIN_ROOT}/scripts/grant-permissions.sh" "$PROJECT_NAME"
        ```
    *   The script is **idempotent** — safe to run on every setup. It patches `~/.claude/settings.json`, adding three entries only if they are not already present:
        *   `Write(~/.flywheel/projects/<PROJECT_NAME>/**)` — file-write tool
        *   `Edit(~/.flywheel/projects/<PROJECT_NAME>/**)` — file-edit tool
        *   `Bash(*~/.flywheel/projects/<PROJECT_NAME>*)` — any shell command referencing the directory
    *   Uses `jq` when available; falls back to `python3`; prints manual instructions if neither is found.
    *   **Message**: "Permissions granted for `~/.flywheel/projects/<PROJECT_NAME>/`"

4.  **Initialize Agents Config**:
    *   Check if `~/.flywheel/agents.yaml` exists.
    *   **If NOT exists**:
        *   Copy the default configuration:
            ```bash
            cp "${CLAUDE_PLUGIN_ROOT}/config/agents.yaml" ~/.flywheel/agents.yaml
            ```
        *   **Message**: "Initialized default agent configuration."

5.  **Migrate Legacy Sessions** (if any):
    *   Check if flat session directories exist at `~/.flywheel/` (implement/, debug/, results/, etc.)
    *   If found, inform the user:
        ```
        ⚠️ Legacy session data found at ~/.flywheel/ (pre-project isolation).
           Run /fw:cleanup migrate-legacy to move it under the current project.
        ```

## Step 2: Install Flywheel Personas

> **Personas are native Claude Code sub-agents.** They give each `/fw:` command a specialist identity with curated tool access, model routing, and clear behavioural mandates — replacing ad-hoc prompt strings with persistent, reusable agents.

1.  **Create the Claude agents directory**:
    ```bash
    mkdir -p ~/.claude/agents
    ```

2.  **Run the persona installer**:
    ```bash
    "${CLAUDE_PLUGIN_ROOT}/scripts/install-personas.sh"
    ```
    This copies all Flywheel personas from `agents/personas/` to `~/.claude/agents/`, only overwriting files that are older than the installed version.

3.  **Verify installation**:
    ```bash
    ls ~/.claude/agents/fw-*.md
    ```
    Expected personas:
    ```
    fw-architect.md          — /fw:design, /fw:implement (planning phases)
    fw-researcher.md         — All research phases (external best practices)
    fw-debugger.md           — /fw:debug (root-cause analysis)
    fw-security-auditor.md   — /fw:harden (OWASP scanning + CVE audit)
    fw-code-reviewer.md      — /fw:review (PR code review)
    fw-tdd-specialist.md     — /fw:tdd (Red → Green → Refactor)
    fw-test-generator.md     — /fw:test (coverage gap analysis)
    fw-migration-engineer.md — /fw:migrate (breaking change handling)
    fw-fe-designer.md        — /fw:design (frontend UI & component tasks)
    ```

4.  **If personas need updating** (e.g. after a plugin upgrade):
    ```bash
    "${CLAUDE_PLUGIN_ROOT}/scripts/install-personas.sh" --force
    ```

## Step 2.5: Agent Teams Configuration (Optional)

> Agent teams enable parallel teammate execution in complex commands (`/fw:implement`, `/fw:review`, `/fw:harden`, etc.). This is an **experimental** Claude Code feature — token usage scales with team size.

1. **Check current status:**
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/team-detect.sh" 2>&1
   ```

2. **If not already enabled**, ask the user:
   ```
   🤝 Would you like to enable experimental agent teams for parallel workflows?

   This allows /fw:implement, /fw:review, /fw:reflect, /fw:harden, and /fw:migrate
   to spawn parallel teammates for independent phases — reducing execution time
   for complex tasks.

   ⚠️  Experimental: CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS feature flag
   ⚠️  Higher token cost: each teammate is a separate Claude instance
   ⚠️  Known limits: no session resumption for in-process teammates, one team per session

   Enable agent teams? [yes / no / skip]
   ```

3. **If yes** — patch `~/.claude/settings.json` to add the feature flag:
   ```bash
   # Using jq (preferred):
   jq '.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1"' ~/.claude/settings.json > /tmp/settings-tmp.json \
     && mv /tmp/settings-tmp.json ~/.claude/settings.json

   # If jq not available, use python3:
   python3 -c "
   import json, sys
   with open(os.path.expanduser('~/.claude/settings.json')) as f:
       s = json.load(f)
   s.setdefault('env', {})['CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS'] = '1'
   with open(os.path.expanduser('~/.claude/settings.json'), 'w') as f:
       json.dump(s, f, indent=2)
   "
   ```

4. **Verify** the setting took effect:
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/team-detect.sh"
   ```

5. **Display result:**
   ```
   ✅ Agent Teams enabled — parallel workflows active
      To disable: set FLYWHEEL_DISABLE_TEAMS=1 or remove the flag from settings.json
      Commands that use teams: /fw:implement, /fw:design, /fw:review, /fw:reflect, /fw:harden, /fw:migrate
   ```
   Or if user skipped:
   ```
   ⏭️  Agent Teams skipped — run /fw:setup again to enable later
   ```

---

## Step 2.7: MCP Server Detection

Flywheel skills depend on optional MCP servers. Check availability and guide installation for any that are missing.

For each required MCP server, attempt to call a lightweight probe (or check `~/.claude/claude.json` for the server entry):

**Servers to check:**

1. **sequential-thinking** — enables structured iterative reasoning in `/fw:debug`, `/fw:design`, `/fw:implement`, `/fw:harden`. See `skills/sequential-thinking/SKILL.md`.
2. **context7** — enables official library documentation enrichment in all research phases. See `skills/context7-research/SKILL.md`.

Display results:
```
🔧 MCP Server Status:
   ✅ sequential-thinking — available (structured reasoning enabled)
   ✅ context7            — available (library docs enrichment enabled)
```

If a server is missing:
```
   ⚠️  sequential-thinking — not found
      Install: claude mcp add sequential-thinking npx @modelcontextprotocol/server-sequential-thinking
      Effect:  /fw:debug, /fw:design, /fw:implement, /fw:harden will skip sequential reasoning (non-blocking)

   ⚠️  context7 — not found
      Install: claude mcp add context7 npx --yes @upstash/context7-mcp
      Effect:  research phases will use WebSearch instead of official library docs (non-blocking)
```

Both skills degrade gracefully — missing MCP servers do not break any command.

---

## Step 3: Detect Providers (was Step 3, renumbered)

1.  **Run provider detection** (force fresh check, ignore cache):
    ```bash
    "${CLAUDE_PLUGIN_ROOT}/scripts/detect-providers.sh" --force
    ```

2.  **Display Results**: Present the detection output to the user.

3.  **Guidance based on results**:
    *   **No providers**: Suggest installing Codex CLI (`npm install -g @openai/codex`) or setting `OPENAI_API_KEY`
    *   **Codex not authenticated**: Suggest `codex login` for OAuth or setting `OPENAI_API_KEY`
    *   **All good**: "Providers ready!"

## Step 4: Verify Configuration (was Step 4, renumbered)

1.  Check that `~/.flywheel/agents.yaml` has at least one agent matching an available provider.
2.  Display available commands:
    *   `/fw:implement` — Full feature workflow (research → plan → build → test)
    *   `/fw:delegate` — Delegate a single task to a sub-agent
    *   `/fw:review` — Multi-agent PR code review
    *   `/fw:debug` — Diagnostic workflow (read-only)
    *   `/fw:tdd` — Test-driven development (Red → Green → Refactor)
    *   `/fw:test` — Proactive test generation and coverage analysis
    *   `/fw:migrate` — Framework/dependency migration with rollback
    *   `/fw:harden` — Security audit (OWASP, CVEs, secrets)
    *   `/fw:fe-design` — Build production-grade frontend interfaces (activates FE-design skill)
    *   `/fw:cleanup` — Manage and clear session caches

3.  Note available cross-cutting skills (MCP server status shown in Step 2.5):
    *   `context7-research` — auto-enriches all research phases with official library documentation. See `skills/context7-research/SKILL.md`.
    *   `sequential-thinking` — activates structured iterative reasoning in analysis phases. See `skills/sequential-thinking/SKILL.md`.
