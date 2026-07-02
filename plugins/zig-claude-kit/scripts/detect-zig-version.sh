#!/bin/bash
# Detect the Zig major.minor version this project targets.
# Prints "0.15" or "0.16" to stdout. Defaults to "0.16" (latest)
# when no signal is available.
#
# Detection priority:
#   1. build.zig.zon's .minimum_zig_version field
#   2. `zig version` if zig is on PATH
#   3. Default to 0.16

set -u

extract_minor() {
  # Input: a version string like "0.15.1" or "0.16.0-dev.123+abc".
  # Output: "0.15" or "0.16" (or empty if not 0.15.x / 0.16.x).
  case "$1" in
    0.15*) echo "0.15" ;;
    0.16*) echo "0.16" ;;
    *)     echo "" ;;
  esac
}

if [ -f build.zig.zon ]; then
  # Anchor the sed pattern on the field name to avoid greedy-.*
  # matching the last quoted string when the .zon is all on one
  # line.
  v=$(sed -nE \
        's/.*minimum_zig_version[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' \
        build.zig.zon 2>/dev/null \
      | head -n 1)
  if [ -n "$v" ]; then
    minor=$(extract_minor "$v")
    if [ -n "$minor" ]; then
      echo "$minor"
      exit 0
    fi
  fi
fi

if command -v zig >/dev/null 2>&1; then
  v=$(zig version 2>/dev/null)
  if [ -n "$v" ]; then
    minor=$(extract_minor "$v")
    if [ -n "$minor" ]; then
      echo "$minor"
      exit 0
    fi
  fi
fi

echo "0.16"
