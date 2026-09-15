#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mode="${1:---all}"
action="add"
if [ "${2:-}" = "--remove" ] || [ "$mode" = "--remove" ]; then
  action="remove"
  [ "$mode" = "--remove" ] && mode="--all"
fi

run_one() {
  local agent="$1"
  local args=(--agent "$agent" --root "$ROOT")
  [ "$action" = "remove" ] && args+=(--remove)
  python3 "$ROOT/scripts/configure_hooks.py" "${args[@]}"
}

case "$mode" in
  --all) run_one claude; run_one codex ;;
  --claude) run_one claude ;;
  --codex) run_one codex ;;
  *)
    echo "Usage: $0 [--all|--claude|--codex] [--remove]" >&2
    exit 2
    ;;
esac

if [ "$action" = "add" ]; then
  cat <<'NOTE'

Hook configuration complete.
- Claude Code: restart running Claude sessions.
- Codex CLI: restart Codex. On builds that require hook trust, open /hooks and approve the new commands.
NOTE
fi
