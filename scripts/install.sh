#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMUX_CONF="${TMUX_CONF:-$HOME/.tmux.conf}"
with_hooks=all

for arg in "$@"; do
  case "$arg" in
    --no-hooks) with_hooks=none ;;
    --claude-only) with_hooks=claude ;;
    --codex-only) with_hooks=codex ;;
    -h|--help)
      cat <<'HELP'
Usage: scripts/install.sh [--no-hooks|--claude-only|--codex-only]

Installs the tmux loader line into ~/.tmux.conf and optionally merges
Claude Code / Codex lifecycle hooks.
HELP
      exit 0
      ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux is required but was not found in PATH." >&2
  exit 1
fi

mkdir -p "$(dirname "$TMUX_CONF")"
touch "$TMUX_CONF"
loader="run-shell '\"$ROOT/agent-status.tmux\"'"

if ! grep -Fq "$ROOT/agent-status.tmux" "$TMUX_CONF"; then
  {
    echo
    echo "# tmux-agent-status"
    echo "$loader"
  } >> "$TMUX_CONF"
  echo "Added tmux-agent-status to $TMUX_CONF"
else
  echo "tmux-agent-status is already referenced by $TMUX_CONF"
fi

case "$with_hooks" in
  all) "$ROOT/scripts/configure-hooks.sh" --all ;;
  claude) "$ROOT/scripts/configure-hooks.sh" --claude ;;
  codex) "$ROOT/scripts/configure-hooks.sh" --codex ;;
  none) ;;
esac

if tmux list-sessions >/dev/null 2>&1; then
  tmux source-file "$TMUX_CONF"
  echo "Reloaded tmux configuration."
else
  echo "No tmux server is running; the plugin will load the next time tmux starts."
fi

cat <<DONE

Installed.

Try:
  $ROOT/bin/doctor

Inside tmux:
  Prefix+s   enhanced session chooser with agent badges
  Prefix+A   same enhanced chooser, dedicated binding

Status legend:
  C● Claude working     X● Codex working
  C! Claude waiting     X! Codex waiting
  C✓ Claude done        X✓ Codex done
DONE
