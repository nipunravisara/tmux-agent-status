# Contributing

Contributions are welcome, especially integrations for other terminal agents.

## Principles

- Prefer lifecycle/events over terminal-output scraping.
- Keep runtime dependencies minimal.
- Never transmit hook payloads or user code by default.
- Preserve existing user configuration during install/uninstall.
- Keep macOS's system Bash 3.2 compatibility where practical.

## Before opening a pull request

```bash
./tests/test.sh
```

If ShellCheck is available:

```bash
shellcheck agent-status.tmux bin/* scripts/*.sh tests/*.sh
```

For changes that affect tmux rendering, also test at least:

- an attached session,
- a detached session,
- `working -> waiting -> working -> done`,
- switching into a completed session,
- re-sourcing `.tmux.conf` twice to check for duplicates.
