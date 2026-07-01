#!/bin/bash
# Detect Zig projects without Tiger Style guidance.
# Runs at Claude Code session start via plugin hook.

# Walk upward from cwd to find the project root -- the
# nearest directory containing build.zig or
# build.zig.zon. Stray .zig files alone do not qualify.
dir="$PWD"
project_root=""
while true; do
  if [ -f "$dir/build.zig" ] || [ -f "$dir/build.zig.zon" ]; then
    project_root="$dir"
    break
  fi
  if [ "$dir" = "/" ]; then
    break
  fi
  dir="$(dirname "$dir")"
done

if [ -z "$project_root" ]; then
  exit 0
fi

# Check if Tiger Style guidance already present.
# Match the fragment heading, not any prose mention.
if grep -q "## Tiger Style" "$project_root/CLAUDE.md" 2>/dev/null; then
  exit 0
fi

FRAGMENT="$(dirname "$0")/../docs/claude-md-fragment.md"

# Inject Tiger Style as immediate context
if [ -f "$FRAGMENT" ]; then
  cat "$FRAGMENT"
  echo ""
fi

# Advisory only -- the guidance above already covers this
# session. Never block on it.
cat <<'INSTRUCTIONS'
The guidance above covers this session only and will be
lost when it ends. Run /tiger-style:tiger-init to persist
it into this project's CLAUDE.md. If this project should
not follow Tiger Style, uninstall the tiger-style plugin.
INSTRUCTIONS
exit 0
