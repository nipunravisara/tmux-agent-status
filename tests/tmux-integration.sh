#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux not installed; skipping tmux integration test."
  exit 0
fi

socket="agent-status-test-$$"
tmp="$(mktemp -d)"
cleanup() {
  tmux -L "$socket" kill-server >/dev/null 2>&1 || true
  rm -rf "$tmp"
}
trap cleanup EXIT

tmux -L "$socket" -f /dev/null new-session -d -s alpha -n shell 'sleep 120'
sleep 0.1

# Load the plugin inside this isolated server.
tmux -L "$socket" run-shell "$ROOT/agent-status.tmux"
sleep 0.1

# Execute state changes inside the pane so TMUX/TMUX_PANE identify the isolated server.
tmux -L "$socket" send-keys -t alpha:0.0 "'$ROOT/bin/agent-status' working CLAUDE" Enter
sleep 0.2
state="$(tmux -L "$socket" show-option -qv -t alpha @agent_status_state)"
agent="$(tmux -L "$socket" show-option -qv -t alpha @agent_status_agent)"
[ "$state" = "working" ]
[ "$agent" = "CLAUDE" ]

tmux -L "$socket" send-keys -t alpha:0.0 "'$ROOT/bin/agent-status' done CLAUDE" Enter
sleep 0.2
state="$(tmux -L "$socket" show-option -qv -t alpha @agent_status_state)"
[ "$state" = "done" ]

sid="$(tmux -L "$socket" display-message -p -t alpha '#{session_id}')"
tmux -L "$socket" send-keys -t alpha:0.0 "'$ROOT/bin/mark-seen' '$sid'" Enter
sleep 0.2
state="$(tmux -L "$socket" show-option -qv -t alpha @agent_status_state)"
[ "$state" = "idle" ]

# Verify the enhanced chooser binding was loaded.
binding="$(tmux -L "$socket" list-keys -T prefix | grep 'choose-tree' | grep -E '(^| )s( |$)' || true)"
[ -n "$binding" ]

echo "tmux integration test passed."
