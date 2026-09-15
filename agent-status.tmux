#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Expose the install path to helper scripts and user config.
tmux set-option -gq @agent-status-root "$ROOT"

# Defaults. Users can set any of these before loading the plugin.
: "${TMUX_AGENT_STATUS_DEFAULT_REBIND:=on}"
if [ -z "$(tmux show-option -gqv @agent-status-rebind-s 2>/dev/null)" ]; then
  tmux set-option -gq @agent-status-rebind-s "$TMUX_AGENT_STATUS_DEFAULT_REBIND"
fi
if [ -z "$(tmux show-option -gqv @agent-status-max 2>/dev/null)" ]; then
  tmux set-option -gq @agent-status-max "6"
fi
if [ -z "$(tmux show-option -gqv @agent-status-show-idle 2>/dev/null)" ]; then
  tmux set-option -gq @agent-status-show-idle "off"
fi

# Append the compact cross-session status renderer once.
status_right="$(tmux show-option -gv status-right 2>/dev/null || true)"
status_cmd="#(\"$ROOT/bin/status-line\")"
case "$status_right" in
  *"$status_cmd"*) ;;
  *) tmux set-option -ag status-right "  $status_cmd" ;;
esac

# Mark completed work as seen when the user switches to that session.
# Indexed hook avoids duplicates after tmux.conf reloads.
tmux set-hook -g 'client-session-changed[100]' "run-shell '\"$ROOT/bin/mark-seen\" \"#{session_id}\"'"

# Enhanced version of tmux's normal Prefix+s session picker.
# Set @agent-status-rebind-s off before loading the plugin to keep tmux's default binding.
if [ "$(tmux show-option -gqv @agent-status-rebind-s 2>/dev/null || echo on)" = "on" ]; then
  tmux bind-key s choose-tree -s -F '#{session_name}: #{session_windows} windows#{?session_attached, (attached),} #{E:@agent_status_badge}'
fi

# A dedicated picker is always available on Prefix+A.
tmux bind-key A choose-tree -s -F '#{session_name}: #{session_windows} windows#{?session_attached, (attached),} #{E:@agent_status_badge}'

tmux refresh-client -S 2>/dev/null || true
