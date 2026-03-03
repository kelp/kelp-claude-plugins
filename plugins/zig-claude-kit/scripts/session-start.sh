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

echo "This is a Zig project missing Zig 0.15.x corrections in CLAUDE.md."
echo "Run /zig-claude-kit:zig-init to add them."
exit 0
