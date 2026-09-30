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

shell='bash --norc --noprofile'
# Created before "alpha" so creation order differs from name order.
tmux -L "$socket" -f /dev/null new-session -d -s zeta -n shell "$shell"
tmux -L "$socket" new-session -d -s alpha -n shell "$shell"
sleep 0.5

# Load the plugin inside this isolated server.
tmux -L "$socket" run-shell "$ROOT/agent-status.tmux"
sleep 0.5

# Execute state changes inside the pane so TMUX/TMUX_PANE identify the isolated server.
tmux -L "$socket" send-keys -t alpha:0.0 "'$ROOT/bin/agent-status' working CLAUDE" Enter
sleep 0.4
state="$(tmux -L "$socket" show-option -qv -t alpha @agent_status_state)"
agent="$(tmux -L "$socket" show-option -qv -t alpha @agent_status_agent)"
[ "$state" = "working" ]
[ "$agent" = "CLAUDE" ]

tmux -L "$socket" send-keys -t alpha:0.0 "'$ROOT/bin/agent-status' done CLAUDE" Enter
sleep 0.4
state="$(tmux -L "$socket" show-option -qv -t alpha @agent_status_state)"
[ "$state" = "done" ]

sid="$(tmux -L "$socket" display-message -p -t alpha '#{session_id}')"
tmux -L "$socket" send-keys -t alpha:0.0 "'$ROOT/bin/mark-seen' '$sid'" Enter
sleep 0.4
state="$(tmux -L "$socket" show-option -qv -t alpha @agent_status_state)"
[ "$state" = "idle" ]

# Chooser badges follow the emoji icon set, including after a reload.
badge="$(tmux -L "$socket" show-option -qv -t alpha @agent_status_badge)"
case "$badge" in *"○ CLAUDE"*) ;; *) echo "unexpected classic badge: $badge" >&2; exit 1 ;; esac
tmux -L "$socket" set-option -g @agent-status-icons emoji
tmux -L "$socket" run-shell "$ROOT/agent-status.tmux"
badge="$(tmux -L "$socket" show-option -qv -t alpha @agent_status_badge)"
case "$badge" in *"😴 CLAUDE"*) ;; *) echo "unexpected emoji badge: $badge" >&2; exit 1 ;; esac
tmux -L "$socket" set-option -g @agent-status-icons classic

# The scanner picks up an agent that was started without hooks.
tmux -L "$socket" send-keys -t zeta:0.0 "(exec -a claude sleep 120)" Enter
sleep 0.3
tmux -L "$socket" run-shell "'$ROOT/bin/scan' --force"
state="$(tmux -L "$socket" show-option -qv -t zeta @agent_status_state)"
agent="$(tmux -L "$socket" show-option -qv -t zeta @agent_status_agent)"
[ "$state" = "idle" ]
[ "$agent" = "CLAUDE" ]

# Status line follows the chooser order (creation order), not name order.
line="$(tmux -L "$socket" run-shell "'$ROOT/bin/status-line'")"
case "$line" in *zeta*alpha*) ;; *) echo "unexpected order: $line" >&2; exit 1 ;; esac

# State for an agent that exited without SessionEnd is cleared.
tmux -L "$socket" send-keys -t zeta:0.0 C-c
sleep 0.3
tmux -L "$socket" set-option -q -t zeta @agent_status_updated 0
tmux -L "$socket" run-shell "'$ROOT/bin/scan' --force"
state="$(tmux -L "$socket" show-option -qv -t zeta @agent_status_state)"
[ -z "$state" ]

# Verify the enhanced chooser binding was loaded.
binding="$(tmux -L "$socket" list-keys -T prefix | grep 'choose-tree' | grep -E '(^| )s( |$)' || true)"
[ -n "$binding" ]

echo "tmux integration test passed."
