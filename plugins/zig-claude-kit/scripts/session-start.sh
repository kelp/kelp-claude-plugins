#!/bin/bash
# Detect Zig projects missing 0.15.x corrections.
# Runs at Claude Code session start via plugin hook.

# Only act in Zig projects
if [ ! -f "build.zig" ] && \
   ! compgen -G "*.zig" > /dev/null 2>&1 && \
   ! compgen -G "src/*.zig" > /dev/null 2>&1; then
  exit 0
fi

# Check if corrections already present
if grep -q "Writergate" CLAUDE.md 2>/dev/null; then
  exit 0
fi

FRAGMENT="$(dirname "$0")/../docs/claude-md-fragment.md"

# Inject corrections as immediate context
if [ -f "$FRAGMENT" ]; then
  cat "$FRAGMENT"
  echo ""
fi

# Instruct Claude to alert the user immediately
cat <<'INSTRUCTIONS'
ACTION REQUIRED: This is a Zig 0.15.x project whose
CLAUDE.md does not contain the necessary training
corrections. Your first message to the user MUST tell
them to run /zig-claude-kit:zig-init to add the
corrections permanently. The patterns above are loaded
for this session only — without running /zig-init they
will be lost when the session ends.
INSTRUCTIONS
exit 0
