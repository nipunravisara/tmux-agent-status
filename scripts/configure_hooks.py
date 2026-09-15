#!/usr/bin/env python3
"""Merge or remove tmux-agent-status lifecycle hooks without clobbering user config."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import sys
import time
from typing import Any

PLUGIN_MARKER = "/bin/hook"

EVENTS = {
    "claude": [
        ("SessionStart", "idle", "CLAUDE"),
        ("UserPromptSubmit", "working", "CLAUDE"),
        ("PreToolUse", "working", "CLAUDE"),
        ("PostToolUse", "working", "CLAUDE"),
        ("PermissionRequest", "waiting", "CLAUDE"),
        ("Stop", "done", "CLAUDE"),
        ("StopFailure", "error", "CLAUDE"),
        ("SessionEnd", "clear", "CLAUDE"),
    ],
    "codex": [
        ("UserPromptSubmit", "working", "CODEX"),
        ("PreToolUse", "working", "CODEX"),
        ("PostToolUse", "working", "CODEX"),
        ("PermissionRequest", "waiting", "CODEX"),
        ("Stop", "done", "CODEX"),
        ("SessionEnd", "clear", "CODEX"),
    ],
}


def config_path(agent: str) -> Path:
    home = Path(os.path.expanduser("~"))
    if agent == "claude":
        return home / ".claude" / "settings.json"
    if agent == "codex":
        return home / ".codex" / "hooks.json"
    raise ValueError(agent)


def load_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Refusing to edit invalid JSON at {path}: {exc}") from exc
    if not isinstance(data, dict):
        raise SystemExit(f"Refusing to edit {path}: top-level JSON must be an object")
    return data


def backup(path: Path) -> Path | None:
    if not path.exists():
        return None
    stamp = time.strftime("%Y%m%d-%H%M%S")
    dest = path.with_name(f"{path.name}.tmux-agent-status.bak-{stamp}")
    shutil.copy2(path, dest)
    return dest


def command_for(root: Path, state: str, agent_label: str) -> str:
    # JSON hook commands are shell commands. Quote the absolute path defensively.
    hook = str((root / "bin" / "hook").resolve()).replace("'", "'\\''")
    return f"'{hook}' {state} {agent_label}"


def is_ours_command(command: str, root: Path | None = None) -> bool:
    root_marker = str((root / "bin" / "hook").resolve()) if root else None
    if root_marker and root_marker in command:
        return True
    return "tmux-agent-status" in command and PLUGIN_MARKER in command


def add_hooks(data: dict[str, Any], agent: str, root: Path) -> int:
    hooks_obj = data.setdefault("hooks", {})
    if not isinstance(hooks_obj, dict):
        raise SystemExit("Refusing to edit config: existing 'hooks' value is not an object")

    added = 0
    for event, state, label in EVENTS[agent]:
        groups = hooks_obj.setdefault(event, [])
        if not isinstance(groups, list):
            raise SystemExit(f"Refusing to edit config: hooks.{event} is not an array")
        expected = command_for(root, state, label)
        already = False
        for group in groups:
            if not isinstance(group, dict):
                continue
            for hook in group.get("hooks", []) if isinstance(group.get("hooks"), list) else []:
                if isinstance(hook, dict) and hook.get("command") == expected:
                    already = True
                    break
            if already:
                break
        if already:
            continue
        groups.append({"hooks": [{"type": "command", "command": expected}]})
        added += 1
    return added


def remove_hooks(data: dict[str, Any], root: Path | None = None) -> int:
    hooks_obj = data.get("hooks")
    if not isinstance(hooks_obj, dict):
        return 0
    removed = 0
    for event in list(hooks_obj.keys()):
        groups = hooks_obj.get(event)
        if not isinstance(groups, list):
            continue
        kept_groups = []
        for group in groups:
            if not isinstance(group, dict):
                kept_groups.append(group)
                continue
            entries = group.get("hooks")
            if not isinstance(entries, list):
                kept_groups.append(group)
                continue
            kept_entries = []
            for entry in entries:
                command = str(entry.get("command", "")) if isinstance(entry, dict) else ""
                if is_ours_command(command, root):
                    removed += 1
                else:
                    kept_entries.append(entry)
            if kept_entries:
                new_group = dict(group)
                new_group["hooks"] = kept_entries
                kept_groups.append(new_group)
        if kept_groups:
            hooks_obj[event] = kept_groups
        else:
            hooks_obj.pop(event, None)
    if not hooks_obj:
        data.pop("hooks", None)
    return removed


def write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--agent", choices=["claude", "codex"], required=True)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--remove", action="store_true")
    args = parser.parse_args()

    path = config_path(args.agent)
    data = load_json(path)

    if args.remove:
        changed = remove_hooks(data, args.root.resolve())
        if not changed:
            print(f"No tmux-agent-status hooks found in {path}")
            return 0
    else:
        changed = add_hooks(data, args.agent, args.root.resolve())
        if not changed:
            print(f"tmux-agent-status hooks already configured in {path}")
            return 0

    bak = backup(path)
    write_json(path, data)
    action = "Removed" if args.remove else "Configured"
    print(f"{action} {changed} hook group(s) in {path}")
    if bak:
        print(f"Backup: {bak}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
