#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMUX_CONF="${TMUX_CONF:-$HOME/.tmux.conf}"

"$ROOT/scripts/configure-hooks.sh" --all --remove || true
"$ROOT/bin/plugin-cleanup" || true

if [ -f "$TMUX_CONF" ]; then
  tmp="$(mktemp)"
  grep -Fv "$ROOT/agent-status.tmux" "$TMUX_CONF" > "$tmp" || true
  mv "$tmp" "$TMUX_CONF"
  echo "Removed loader line from $TMUX_CONF"
fi

cat <<DONE

Uninstalled tmux-agent-status configuration.
The repository itself was not deleted:
  $ROOT

Delete that directory manually if you no longer want it.
DONE
