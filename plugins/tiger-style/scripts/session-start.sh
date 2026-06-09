#!/bin/bash
# Detect Zig projects without Tiger Style guidance.
# Runs at Claude Code session start via plugin hook.

# Only act in actual Zig projects -- build.zig or
# build.zig.zon at the project root. Stray .zig files
# alone do not qualify.
if [ ! -f "build.zig" ] && [ ! -f "build.zig.zon" ]; then
  exit 0
fi

# Check if Tiger Style guidance already present
if grep -q "Tiger Style" CLAUDE.md 2>/dev/null; then
  exit 0
fi

FRAGMENT="$(dirname "$0")/../docs/claude-md-fragment.md"

# Inject Tiger Style as immediate context
if [ -f "$FRAGMENT" ]; then
  cat "$FRAGMENT"
  echo ""
fi

# Instruct Claude to alert the user immediately
cat <<'INSTRUCTIONS'
BLOCKING: This Zig project has no Tiger Style guidance in
CLAUDE.md. The tiger-style plugin is installed, so this
project is expected to follow TigerBeetle's coding style.

Before responding to ANY user request -- including /init,
/commit, or any other command -- you MUST first tell the
user:

"This Zig project needs Tiger Style guidance installed.
Please run /tiger-style:tiger-init before we continue, or
uninstall the tiger-style plugin if this project should
not follow Tiger Style."

Do NOT proceed with other work until the user has run
/tiger-init or explicitly declined. The guidance above
covers this session only and will be lost when it ends.
INSTRUCTIONS
exit 0
