# Architecture

`tmux-agent-status` deliberately keeps the tmux side small. Claude Code and Codex already know when a turn starts, requests permission, finishes, or exits, so the plugin listens to those lifecycle events rather than scraping terminal output.

## Event flow

```text
Claude Code / Codex
        |
        | lifecycle hook
        v
   bin/hook
        |
        v
 bin/agent-status
        |
        | $TMUX_PANE -> owning session
        v
 tmux session user options
        |
        +--> enhanced Prefix+s chooser
        |
        +--> status-right cross-session summary
```

## Stored tmux user options

Each session can carry these user options:

- `@agent_status_state` — `working`, `waiting`, `done`, `error`, or `idle`
- `@agent_status_agent` — normally `CLAUDE` or `CODEX`
- `@agent_status_updated` — Unix timestamp of the last state transition
- `@agent_status_pane` — pane that emitted the state
- `@agent_status_project` — basename of the pane's working directory
- `@agent_status_unread` — `0` or `1`
- `@agent_status_badge` — tmux-formatted badge used by `choose-tree`

No persistent database is used. Restarting the tmux server clears the runtime statuses naturally.

## State semantics

```text
prompt submitted  -> working
permission needed -> waiting
tool activity      -> working
turn stops         -> done
turn fails         -> error (Claude StopFailure)
session exits      -> clear
```

A `done` state stays highlighted until the user switches into that session (or sends another prompt there). The `client-session-changed` tmux hook then marks it seen.

`waiting` and `error` are intentionally not auto-cleared by visiting the session. They are conditions that usually still require attention.

## Why session options instead of files

Using tmux user options means:

- no temporary-file cleanup,
- no locking,
- no stale state after the tmux server exits,
- the chooser can render the state directly,
- multiple tmux servers remain naturally isolated.

## Codex fallback

Codex also supports an external `notify` command for completed turns. `bin/codex-notify` can be configured as a completion-only fallback if a specific Codex release has lifecycle-hook issues. It cannot provide the full `working`/`waiting` state by itself.
