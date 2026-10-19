#!/usr/bin/env bash
# Register the SkillSpector gate globally: copy the hook scripts to ~/.claude/hooks
# and merge SessionStart + PreToolUse entries into ~/.claude/settings.json.
# Idempotent; existing settings are preserved.
set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dest="$HOME/.claude/hooks"
mkdir -p "$dest"
install -m 755 "$src/skillspector-gate.py" "$dest/skillspector-gate.py"
install -m 755 "$src/install-skillspector.sh" "$dest/install-skillspector.sh"
if [ -f "$src/skillspector-allow.json" ]; then install -m 644 "$src/skillspector-allow.json" "$dest/skillspector-allow.json"; fi

python3 -I - "$HOME/.claude/settings.json" "$dest" <<'EOF'
import json, sys
from pathlib import Path

path, dest = Path(sys.argv[1]), sys.argv[2]
settings = json.loads(path.read_text()) if path.exists() and path.read_text().strip() else {}
hooks = settings.setdefault("hooks", {})

wanted = {
    "SessionStart": {"hooks": [{"type": "command", "timeout": 600,
                                "command": f'bash "{dest}/install-skillspector.sh"'}]},
    "PreToolUse": {"matcher": "Bash|Write|Edit|MultiEdit",
                   "hooks": [{"type": "command", "timeout": 600,
                              "command": f'python3 -I "{dest}/skillspector-gate.py"'}]},
}
for event, entry in wanted.items():
    marker = Path(entry["hooks"][0]["command"].split('"')[1]).name
    groups = [g for g in hooks.get(event, [])
              if not any(marker in h.get("command", "") for h in g.get("hooks", []))]
    groups.append(entry)
    hooks[event] = groups

path.write_text(json.dumps(settings, indent=2) + "\n")
print(f"SkillSpector-Gate global registriert in {path}", file=sys.stderr)
EOF
