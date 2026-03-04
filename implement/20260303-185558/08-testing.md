# Phase 8 — Testing

## Automated Checks

| Check | Result |
|-------|--------|
| team-detect.sh exists and is executable | ✅ |
| team-templates.yaml is valid YAML | ✅ |
| All 6 commands have `## Team Configuration` header | ✅ |
| All 6 commands have `[TEAM MODE]` blocks | ✅ (1-4 per command) |
| All 6 commands have `[SEQUENTIAL MODE]` blocks | ✅ |
| team-detect.sh exits 1 when flag unset | ✅ |
| team-detect.sh exits 0 when CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 | ✅ |
| FLYWHEEL_DISABLE_TEAMS=1 overrides to exit 1 | ✅ |
| JSON output is valid | ✅ |
| setup.md has Agent Teams step | ✅ |
| cleanup.md has teams target | ✅ |
| CLAUDE.md updated with new section and env vars | ✅ |
| plugin.json bumped to 1.1.0 | ✅ |

## Coverage Gaps

- No end-to-end test of actual agent team spawn (requires CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS enabled at runtime)
- No validation that all 5 team templates in team-templates.yaml reference existing personas
