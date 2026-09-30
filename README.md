# tmux-agent-status

See **Claude Code** and **OpenAI Codex** task state across tmux sessions without switching into every session.

```text
 main C●  │  whereto X✓  │  spendwise C!  │  api X●
```

The normal tmux session chooser is enhanced too:

```text
(0) + main:      1 windows (attached)   ● CLAUDE
(1) + whereto:   1 windows              ✓ CODEX
(2) + spendwise: 1 windows              ! CLAUDE
(3) + api:       1 windows              ● CODEX
```

## What the states mean

| Badge | State | Meaning |
| --- | --- | --- |
| `C●` / `X●` | working | Claude / Codex is processing a turn |
| `C!` / `X!` | waiting | the agent needs permission / user attention |
| `C✓` / `X✓` | done | a background session finished a turn |
| `C×` / `X×` | error | the agent reported a failed turn (currently Claude `StopFailure`) |
| `C○` / `X○` | idle | an agent is open in the session but not doing anything |

`C` means Claude and `X` means Codex.

Prefer something more fun? Switch to the [emoji icon set](#emoji-icons):

```text
🐙 zenin  main 🎉 │ whereto 🔥 │ spendwise 🙋 │ api 💥
```

The session chooser uses the same emojis:

```text
(0) + main:      1 windows (attached)   🎉 CLAUDE
(1) + whereto:   1 windows              🔥 CODEX
(2) + spendwise: 1 windows              🙋 CLAUDE
(3) + api:       1 windows              💥 CODEX
```

## Why this works well

The plugin does **not** scrape terminal text. It uses the lifecycle hooks exposed by Claude Code and Codex, maps the hook process back to its owning tmux session through `$TMUX_PANE`, and stores the state in tmux user options.

That makes it fast, deterministic, and independent of what the model happens to print.

## Requirements

- tmux
- Bash 3.2+ (works with the Bash shipped on macOS)
- Python 3 only for the hook configuration installer
- Claude Code and/or Codex CLI if you want automatic agent tracking

The runtime status scripts themselves do not require Python, Node, `jq`, or a daemon.

# Installation

## Option A — easiest: clone + installer

After pushing this repository to GitHub, clone it where you keep tmux plugins:

```bash
git clone https://github.com/YOUR_USERNAME/tmux-agent-status.git ~/.tmux/plugins/tmux-agent-status
~/.tmux/plugins/tmux-agent-status/scripts/install.sh
```

The installer:

1. adds the plugin loader to `~/.tmux.conf`,
2. safely merges Claude hooks into `~/.claude/settings.json`,
3. safely merges Codex hooks into `~/.codex/hooks.json`,
4. creates timestamped backups before changing existing JSON files,
5. reloads tmux when a server is already running.

Agents that were already running before installation are picked up automatically as idle (see [Process detection](#process-detection)). Restart them to get full working/waiting/done tracking through hooks.

For Codex, if the CLI asks you to trust newly discovered hooks, open `/hooks` and approve the commands.

### Install only one integration

```bash
# tmux + Claude hooks only
~/.tmux/plugins/tmux-agent-status/scripts/install.sh --claude-only

# tmux + Codex hooks only
~/.tmux/plugins/tmux-agent-status/scripts/install.sh --codex-only

# install the tmux plugin without touching agent hook files
~/.tmux/plugins/tmux-agent-status/scripts/install.sh --no-hooks
```

## Option B — TPM (Tmux Plugin Manager)

Add this to `.tmux.conf`:

```tmux
set -g @plugin 'YOUR_USERNAME/tmux-agent-status'
```

Press `Prefix + I` to install through TPM, then configure the lifecycle hooks once:

```bash
~/.tmux/plugins/tmux-agent-status/scripts/configure-hooks.sh --all
```

If your TPM directory is different, run the script from that clone instead.

## Option C — manual source

Clone anywhere and add:

```tmux
run-shell '/absolute/path/to/tmux-agent-status/agent-status.tmux'
```

Then configure integrations:

```bash
/absolute/path/to/tmux-agent-status/scripts/configure-hooks.sh --all
```

# Usage

There is nothing special to launch.

Start Claude or Codex normally **inside tmux**:

```bash
tmux new -s whereto
claude
```

or:

```bash
tmux new -s backend
codex
```

Send a task, switch to another tmux session, and keep working. The cross-session indicator in the status bar (`status-right` by default) updates as agents change state.

## Session chooser

By default, the plugin upgrades the standard:

```text
Prefix+s
```

session picker so it includes an agent badge at the right side.

A dedicated binding is also always installed:

```text
Prefix+A
```

When you switch into a session showing `✓`, the completed indicator is automatically marked as seen and disappears. `!` and `×` stay visible because they usually still require attention.

# Configuration

Set options **before** loading `agent-status.tmux` (or before the TPM `run` line).

## Keep the original Prefix+s binding

```tmux
set -g @agent-status-rebind-s off
```

The enhanced picker remains available at `Prefix+A`.

## Limit status-bar sessions

Default: 6.

```tmux
set -g @agent-status-max 4
```

If more active agent sessions exist, the status bar shows `+N`.

## Hide idle agents

Idle agents are shown by default. To show only sessions with activity:

```tmux
set -g @agent-status-show-idle off
```

Then reload:

```bash
tmux source-file ~/.tmux.conf
```

## Process detection

Hooks only fire for agents started after the hooks were installed, and an agent that is killed never reports `SessionEnd`. To cover both cases the plugin also scans each pane's process tree (on every status refresh, and whenever the session picker opens):

- an agent running in a session with no state is shown as idle,
- state left behind by an agent that has exited is cleared.

Detected process names and their labels are configurable (`process:LABEL`, space separated):

```tmux
set -g @agent-status-agents 'claude:CLAUDE codex:CODEX gemini:GEMINI opencode:OPENCODE aider:AIDER cursor-agent:CURSOR'
```

Agents without hooks only get idle presence, not working/done. Turn scanning off with:

```tmux
set -g @agent-status-detect off
```

## Session order

The status bar lists sessions in the same order as the `Prefix+s` picker, which is session creation order.

## Emoji icons

Replace the compact `C●` / `X!` badges with emojis:

```tmux
set -g @agent-status-icons emoji
```

| State | Default emoji | Override option |
| --- | --- | --- |
| working | 🔥 | `@agent-status-icon-working` |
| waiting | 🙋 | `@agent-status-icon-waiting` |
| done | 🎉 | `@agent-status-icon-done` |
| error | 💥 | `@agent-status-icon-error` |
| idle | 😴 | `@agent-status-icon-idle` |

Pick your own for any state:

```tmux
set -g @agent-status-icon-working '🤖'
set -g @agent-status-icon-idle '💤'
```

The same emojis are used in the status bar and the `Prefix+s` / `Prefix+A` session chooser. The status bar does not tell Claude from Codex in emoji mode; the chooser still shows the agent name next to the emoji (`🔥 CLAUDE`).

Reloading tmux (`tmux source-file ~/.tmux.conf`) re-renders chooser badges for sessions that already have a state, so switching icon sets applies right away.

Your terminal font must be able to show emojis. Emojis with a variation selector (for example `✔️`) can take up the wrong width in tmux, so plain emojis like the defaults work best.

## Status bar position

The indicator is added to `status-right` by default. To show it on the left, after your `status-left` text:

```tmux
set -g status-left '🐙 #[fg=green]zenin  '
set -g @agent-status-position left
```

Set `status-left` **before** loading the plugin, because the plugin appends to it. In `left` mode the plugin also raises `status-left-length` to 100 if it is lower. tmux's default is 10, which would hide the badges.

# Lifecycle mappings

## Claude Code

The installer adds these global hooks:

| Claude event | tmux state |
| --- | --- |
| `SessionStart` | idle |
| `UserPromptSubmit` | working |
| `PreToolUse` | working |
| `PostToolUse` | working |
| `PermissionRequest` | waiting |
| `Stop` | done |
| `StopFailure` | error |
| `SessionEnd` | clear |

`PostToolUse -> working` clears `waiting` after an approved tool finishes, while subsequent tool activity keeps the state accurate.

## Codex CLI

The installer adds:

| Codex event | tmux state |
| --- | --- |
| `UserPromptSubmit` | working |
| `PreToolUse` | working |
| `PostToolUse` | working |
| `PermissionRequest` | waiting |
| `Stop` | done |
| `SessionEnd` | clear |

Codex hooks have evolved rapidly across versions. Current Codex source includes these lifecycle events, but some past releases have had hook-dispatch regressions. See the completion-only fallback below if your installed release is affected.

# Codex completion fallback

Codex has an external `notify` integration that can run a command after an agent turn completes. This repository includes:

```text
bin/codex-notify
```

If lifecycle hooks do not fire reliably in your Codex build, add this **top-level** entry to `~/.codex/config.toml`, using the real absolute path:

```toml
notify = ["bash", "/Users/YOU/.tmux/plugins/tmux-agent-status/bin/codex-notify"]
```

This fallback provides `done` detection only. Lifecycle hooks remain the preferred path because they can show `working` and `waiting` as well.

# Existing hook files are preserved

The installer does not replace your whole Claude or Codex configuration. It appends its own hook groups and leaves unrelated settings/hooks in place.

Before modifying an existing JSON file it creates a backup such as:

```text
settings.json.tmux-agent-status.bak-20260915-190455
hooks.json.tmux-agent-status.bak-20260915-190455
```

You can inspect example hook structures in:

```text
integrations/claude-hooks.example.json
integrations/codex-hooks.example.json
```

# Manual testing

Inside a tmux pane:

```bash
~/.tmux/plugins/tmux-agent-status/bin/agent-status working TEST
```

You should see the current session appear as `A●`.

Try the other states:

```bash
~/.tmux/plugins/tmux-agent-status/bin/agent-status waiting TEST
~/.tmux/plugins/tmux-agent-status/bin/agent-status done TEST
~/.tmux/plugins/tmux-agent-status/bin/agent-status error TEST
~/.tmux/plugins/tmux-agent-status/bin/agent-status clear
```

# Doctor

Run:

```bash
~/.tmux/plugins/tmux-agent-status/bin/doctor
```

It reports:

- tmux availability/server state,
- current per-session agent states,
- Claude/Codex versions when found,
- whether the plugin hook commands exist in the expected config files.

For more detail see [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

# Project layout

```text
tmux-agent-status/
├── agent-status.tmux             # tmux plugin entrypoint
├── bin/
│   ├── agent-status              # core session state writer
│   ├── hook                      # lifecycle-hook stdin adapter
│   ├── status-line               # all-session status renderer
│   ├── mark-seen                 # clears visited completed sessions
│   ├── clear-all                 # clears runtime state
│   ├── codex-notify              # Codex completion fallback
│   ├── doctor                    # diagnostics
│   └── plugin-cleanup            # runtime uninstall cleanup
├── scripts/
│   ├── install.sh
│   ├── uninstall.sh
│   ├── configure-hooks.sh
│   └── configure_hooks.py
├── integrations/
│   ├── claude-hooks.example.json
│   └── codex-hooks.example.json
├── docs/
│   ├── ARCHITECTURE.md
│   └── TROUBLESHOOTING.md
└── tests/
    └── test.sh
```

# Development

Run repository self-tests:

```bash
./tests/test.sh
```

If ShellCheck is installed:

```bash
shellcheck agent-status.tmux bin/* scripts/*.sh tests/*.sh
```

The GitHub Actions workflow runs syntax/configuration tests on pushes and pull requests.

# Uninstall

```bash
~/.tmux/plugins/tmux-agent-status/scripts/uninstall.sh
```

This removes the loader line, removes only the lifecycle hook groups owned by this plugin, clears runtime state, and restores the standard `Prefix+s` chooser. It does **not** delete the cloned repository.

# Notes on security

Claude Code and Codex lifecycle hooks execute local commands. This plugin's hook command only:

1. reads the inherited tmux environment,
2. determines the owning tmux session,
3. sets tmux user options,
4. refreshes the tmux client.

It does not send model prompts, code, transcripts, or hook payloads over the network. The `bin/hook` adapter discards the JSON event payload from stdin.

You should still review hook commands before trusting them, especially when installing any third-party repository.

# Documentation references

- Claude Code hooks: https://code.claude.com/docs/en/hooks
- Claude Code hooks guide: https://code.claude.com/docs/en/hooks-guide
- OpenAI Codex repository: https://github.com/openai/codex

# License

MIT — see [LICENSE](LICENSE).
