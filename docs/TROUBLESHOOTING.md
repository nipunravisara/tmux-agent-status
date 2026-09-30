# Troubleshooting

## Start with the doctor

```bash
~/.tmux/plugins/tmux-agent-status/bin/doctor
```

If the repository lives elsewhere, run `bin/doctor` from that clone.

## The status bar never changes

The lifecycle command needs to run inside a process that was started inside tmux so it inherits `TMUX` and `TMUX_PANE`.

Inside the Claude/Codex pane, check:

```bash
echo "$TMUX"
echo "$TMUX_PANE"
```

Both should be non-empty.

Then manually test:

```bash
/path/to/tmux-agent-status/bin/agent-status working TEST
```

The current session should immediately show `A●` in the cross-session status display. Use `clear` when done:

```bash
/path/to/tmux-agent-status/bin/agent-status clear
```

## Claude hooks are not firing

1. Confirm `~/.claude/settings.json` contains the plugin hook commands.
2. Restart the Claude Code process after changing hooks.
3. Re-run:

```bash
/path/to/tmux-agent-status/scripts/configure-hooks.sh --claude
```

The installer merges its entries; it does not replace unrelated hooks.

Claude Code hook documentation:

- https://code.claude.com/docs/en/hooks
- https://code.claude.com/docs/en/hooks-guide

## Codex hooks are not firing

Codex lifecycle hooks have changed rapidly across releases. First:

```bash
codex --version
codex features list
```

On current releases, verify that the `hooks` feature is enabled. Codex may also require you to review/trust newly discovered hooks using `/hooks` in the interactive CLI.

Then verify `~/.codex/hooks.json` contains the plugin commands and restart Codex.

### Completion-only Codex fallback

If your Codex build has a hook regression but its external notifier works, add the following top-level setting to `~/.codex/config.toml` using the real absolute path:

```toml
notify = ["bash", "/Users/YOU/.tmux/plugins/tmux-agent-status/bin/codex-notify"]
```

Codex appends a JSON payload to that command after a completed turn. The fallback marks the tmux session as `done`. Lifecycle hooks are still preferred because they can also show `working` and `waiting`.

## Prefix+s no longer looks right

The plugin intentionally enhances the standard session chooser. To keep tmux's original Prefix+s binding, put this **before** loading the plugin:

```tmux
set -g @agent-status-rebind-s off
```

You can still open the enhanced chooser with `Prefix+A`.

## Status-right is too crowded

Limit the number of agent sessions shown:

```tmux
set -g @agent-status-max 3
```

Idle agents are shown by default. To hide them:

```tmux
set -g @agent-status-show-idle off
```

Reload:

```bash
tmux source-file ~/.tmux.conf
```

## Clear stale state manually

```bash
/path/to/tmux-agent-status/bin/clear-all
```

## Existing hook configuration

The hook installer creates timestamped backups before it changes an existing JSON file. Look beside:

- `~/.claude/settings.json`
- `~/.codex/hooks.json`

for files containing `.tmux-agent-status.bak-...`.
