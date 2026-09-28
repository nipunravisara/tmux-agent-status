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

if [ -z "$(tmux show-option -gqv @agent-status-position 2>/dev/null)" ]; then
  tmux set-option -gq @agent-status-position "right"
fi
if [ -z "$(tmux show-option -gqv @agent-status-icons 2>/dev/null)" ]; then
  tmux set-option -gq @agent-status-icons "classic"
fi

# Append the compact cross-session status renderer once, to status-left or
# status-right, and remove it from the other side so switching sides on reload works.
status_cmd="#(\"$ROOT/bin/status-line\")"
position="$(tmux show-option -gqv @agent-status-position 2>/dev/null || true)"
case "$position" in
  left) target=status-left; other=status-right ;;
  *)    target=status-right; other=status-left ;;
esac

other_value="$(tmux show-option -gv "$other" 2>/dev/null || true)"
case "$other_value" in
  *"$status_cmd"*) tmux set-option -g "$other" "${other_value//  $status_cmd/}" ;;
esac

target_value="$(tmux show-option -gv "$target" 2>/dev/null || true)"
case "$target_value" in
  *"$status_cmd"*) ;;
  *) tmux set-option -ag "$target" "  $status_cmd" ;;
esac

# tmux truncates status-left at 10 cells by default, which would hide the badges.
if [ "$target" = "status-left" ]; then
  left_len="$(tmux show-option -gv status-left-length 2>/dev/null || echo 10)"
  case "$left_len" in ''|*[!0-9]*) left_len=10 ;; esac
  [ "$left_len" -ge 100 ] || tmux set-option -g status-left-length 100
fi

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
