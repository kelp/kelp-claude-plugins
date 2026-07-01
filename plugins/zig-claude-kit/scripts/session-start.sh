#!/bin/bash
# Detect Zig projects missing 0.15.x corrections.
# Runs at Claude Code session start via plugin hook.

# Walk upward from cwd to find the nearest directory
# containing build.zig or build.zig.zon. Stray .zig files
# alone do not qualify, and a project root above cwd (e.g.
# when Claude starts in a subdirectory) still counts.
project_root=""
dir="$PWD"
while [ "$dir" != "/" ]; do
  if [ -f "$dir/build.zig" ] || [ -f "$dir/build.zig.zon" ]; then
    project_root="$dir"
    break
  fi
  dir="$(dirname "$dir")"
done

if [ -z "$project_root" ]; then
  exit 0
fi

# Check if corrections already present, anchored to the
# fragment's own heading so unrelated mentions don't count.
if grep -q "^## Zig 0.15.x Training Corrections" \
    "$project_root/CLAUDE.md" 2>/dev/null; then
  exit 0
fi

FRAGMENT="$(dirname "$0")/../docs/claude-md-fragment.md"

# Inject corrections as immediate context
if [ -f "$FRAGMENT" ]; then
  cat "$FRAGMENT"
  echo ""
fi

# Advise the user; corrections above already apply to this
# session regardless.
cat <<'INSTRUCTIONS'
The corrections above cover this session only. Run
/zig-claude-kit:zig-init to add them to CLAUDE.md so future
sessions get them automatically.
INSTRUCTIONS
exit 0
