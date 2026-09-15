#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[1/5] bash syntax"
while IFS= read -r file; do
  bash -n "$file"
done < <(find "$ROOT" -type f \( -name '*.sh' -o -name '*.tmux' -o -path '*/bin/*' \) ! -name '*.json' ! -name '*.md' ! -name '*.py' -print)

echo "[2/5] python syntax"
python3 -m py_compile "$ROOT/scripts/configure_hooks.py"

echo "[3/5] hook merge/idempotency"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/.claude" "$tmp/.codex"
cat > "$tmp/.claude/settings.json" <<'JSON'
{
  "permissions": {"allow": ["Bash(git status:*)"]},
  "hooks": {
    "Stop": [
      {"hooks": [{"type": "command", "command": "echo existing-stop-hook"}]}
    ]
  }
}
JSON
cat > "$tmp/.codex/hooks.json" <<'JSON'
{
  "hooks": {
    "UserPromptSubmit": [
      {"hooks": [{"type": "command", "command": "echo existing-codex-hook"}]}
    ]
  }
}
JSON

HOME="$tmp" python3 "$ROOT/scripts/configure_hooks.py" --agent claude --root "$ROOT" >/dev/null
HOME="$tmp" python3 "$ROOT/scripts/configure_hooks.py" --agent codex --root "$ROOT" >/dev/null
HOME="$tmp" python3 "$ROOT/scripts/configure_hooks.py" --agent claude --root "$ROOT" >/dev/null
HOME="$tmp" python3 "$ROOT/scripts/configure_hooks.py" --agent codex --root "$ROOT" >/dev/null

python3 - "$tmp" "$ROOT" <<'PY'
import json
import pathlib
import sys

tmp = pathlib.Path(sys.argv[1])
root = pathlib.Path(sys.argv[2]).resolve()
marker = str(root / "bin" / "hook")

claude = json.loads((tmp / ".claude/settings.json").read_text())
assert claude["permissions"]["allow"] == ["Bash(git status:*)"]
assert any(h.get("command") == "echo existing-stop-hook" for g in claude["hooks"]["Stop"] for h in g.get("hooks", []))
for event in ["SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "PermissionRequest", "Stop", "StopFailure", "SessionEnd"]:
    found = [h for g in claude["hooks"][event] for h in g.get("hooks", []) if marker in h.get("command", "")]
    assert len(found) == 1, (event, found)

codex = json.loads((tmp / ".codex/hooks.json").read_text())
assert any(h.get("command") == "echo existing-codex-hook" for g in codex["hooks"]["UserPromptSubmit"] for h in g.get("hooks", []))
for event in ["UserPromptSubmit", "PreToolUse", "PostToolUse", "PermissionRequest", "Stop", "SessionEnd"]:
    found = [h for g in codex["hooks"][event] for h in g.get("hooks", []) if marker in h.get("command", "")]
    assert len(found) == 1, (event, found)
PY

echo "[4/5] hook removal preserves unrelated config"
HOME="$tmp" python3 "$ROOT/scripts/configure_hooks.py" --agent claude --root "$ROOT" --remove >/dev/null
HOME="$tmp" python3 "$ROOT/scripts/configure_hooks.py" --agent codex --root "$ROOT" --remove >/dev/null
python3 - "$tmp" <<'PY'
import json
import pathlib
import sys

tmp = pathlib.Path(sys.argv[1])
claude = json.loads((tmp / ".claude/settings.json").read_text())
assert claude["permissions"]["allow"] == ["Bash(git status:*)"]
assert any(h.get("command") == "echo existing-stop-hook" for g in claude["hooks"]["Stop"] for h in g.get("hooks", []))
codex = json.loads((tmp / ".codex/hooks.json").read_text())
assert any(h.get("command") == "echo existing-codex-hook" for g in codex["hooks"]["UserPromptSubmit"] for h in g.get("hooks", []))
PY

echo "[5/5] tmux integration (when tmux is installed)"
"$ROOT/tests/tmux-integration.sh"

echo "All tests passed."
