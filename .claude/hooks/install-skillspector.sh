#!/usr/bin/env bash
# Install NVIDIA SkillSpector from the official repo, pinned to a reviewed commit.
# Runs as a SessionStart hook; no-op when the pinned version is already installed.
set -euo pipefail

SKILLSPECTOR_REPO="https://github.com/NVIDIA/SkillSpector.git"
SKILLSPECTOR_COMMIT="cf5cac7ba5c756a6e0ebf52dc9763f49422f889f"  # v2.12.0
export PATH="$HOME/.local/bin:$PATH"

stamp="$HOME/.local/share/skillspector-gate/commit"
if command -v skillspector >/dev/null 2>&1 && [ "$(cat "$stamp" 2>/dev/null)" = "$SKILLSPECTOR_COMMIT" ]; then
  exit 0
fi

if ! command -v uv >/dev/null 2>&1; then
  python3 -m pip install --user --quiet uv
fi

uv tool install --force --quiet "git+${SKILLSPECTOR_REPO}@${SKILLSPECTOR_COMMIT}" >&2
mkdir -p "$(dirname "$stamp")"
echo "$SKILLSPECTOR_COMMIT" > "$stamp"
echo "SkillSpector $(skillspector --version 2>/dev/null) installiert (${SKILLSPECTOR_COMMIT:0:12})" >&2
