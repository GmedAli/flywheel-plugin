#!/usr/bin/env bash
# Grant Claude Code permissions for a Flywheel project directory.
# Writes to ~/.claude/settings.json so that Write, Edit, and Bash tool calls
# targeting the project's data directory are auto-approved without prompts.
#
# Usage:  grant-permissions.sh <PROJECT_NAME>
# Example: grant-permissions.sh flywheel-backend

set -euo pipefail

PROJECT_NAME="${1:-}"
if [[ -z "$PROJECT_NAME" ]]; then
  echo "Usage: $0 <PROJECT_NAME>" >&2
  exit 1
fi

PROJECT_DIR="$HOME/.flywheel/projects/$PROJECT_NAME"
SETTINGS="$HOME/.claude/settings.json"

# Permissions to inject — covers CRUD for file tools and any shell command
# that references the project directory.
NEW_PERMS=(
  "Write($PROJECT_DIR/**)"
  "Edit($PROJECT_DIR/**)"
  "Bash(*$PROJECT_DIR*)"
)

# ── Ensure settings file exists ───────────────────────────────────────────────
if [[ ! -f "$SETTINGS" ]]; then
  mkdir -p "$(dirname "$SETTINGS")"
  printf '{\n  "permissions": {\n    "allow": []\n  }\n}\n' > "$SETTINGS"
fi

# ── Patch with jq (preferred) ─────────────────────────────────────────────────
_patch_with_jq() {
  local perm
  for perm in "${NEW_PERMS[@]}"; do
    local already
    already=$(jq -r '.permissions.allow // [] | .[]' "$SETTINGS" 2>/dev/null | grep -Fx "$perm" || true)
    if [[ -z "$already" ]]; then
      local tmp
      tmp=$(mktemp)
      jq --arg p "$perm" '
        .permissions //= {}
        | .permissions.allow //= []
        | .permissions.allow += [$p]
      ' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
      echo "  ✅ Granted: $perm"
    else
      echo "  ✓  Already set: $perm"
    fi
  done
}

# ── Patch with Python 3 (fallback) ────────────────────────────────────────────
_patch_with_python() {
  python3 - "$SETTINGS" "${NEW_PERMS[@]}" <<'PYEOF'
import json, sys, pathlib

settings_path = pathlib.Path(sys.argv[1])
new_perms = sys.argv[2:]

data = json.loads(settings_path.read_text()) if settings_path.exists() else {}
allow = data.setdefault("permissions", {}).setdefault("allow", [])

for perm in new_perms:
    if perm in allow:
        print(f"  \u2713  Already set: {perm}")
    else:
        allow.append(perm)
        print(f"  \u2705 Granted: {perm}")

settings_path.write_text(json.dumps(data, indent=2) + "\n")
PYEOF
}

# ── Manual fallback ───────────────────────────────────────────────────────────
_print_manual_instructions() {
  echo ""
  echo "  ⚠️  Could not auto-patch settings (jq and python3 not found)."
  echo "  Add these entries to ~/.claude/settings.json manually:"
  echo ""
  echo '  "permissions": {'
  echo '    "allow": ['
  for perm in "${NEW_PERMS[@]}"; do
    echo "      \"$perm\","
  done
  echo '    ]'
  echo '  }'
}

# ── Dispatch ──────────────────────────────────────────────────────────────────
echo "Granting permissions for project: $PROJECT_NAME"
echo "  Directory: $PROJECT_DIR"

if command -v jq &>/dev/null; then
  _patch_with_jq
elif command -v python3 &>/dev/null; then
  _patch_with_python
else
  _print_manual_instructions
fi
