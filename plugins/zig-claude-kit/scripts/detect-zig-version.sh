#!/usr/bin/env bash
# detect-zig-version.sh - Identify which Zig version the project targets.
#
# Outputs "0.15" or "0.16" on stdout. Defaults to 0.16 (the current
# release) when nothing is detected. Never errors.
#
# Detection order:
#   1. build.zig.zon's minimum_zig_version field
#   2. Installed `zig version`
#   3. Fallback: 0.16

set -u

# 1. Read minimum_zig_version from build.zig.zon
if [ -f "build.zig.zon" ]; then
    version=$(grep -oE 'minimum_zig_version[[:space:]]*=[[:space:]]*"[^"]+"' \
        build.zig.zon 2>/dev/null \
        | sed -E 's/.*"([^"]+)"/\1/')
    case "$version" in
        0.15*) echo "0.15"; exit 0 ;;
        0.16*) echo "0.16"; exit 0 ;;
        0.17*|0.18*|0.19*|0.[2-9]*|[1-9].*) echo "0.16"; exit 0 ;;
    esac
fi

# 2. Try installed zig compiler
if command -v zig >/dev/null 2>&1; then
    version=$(zig version 2>/dev/null)
    case "$version" in
        0.15*) echo "0.15"; exit 0 ;;
        0.16*) echo "0.16"; exit 0 ;;
        0.17*|0.18*|0.19*|0.[2-9]*|[1-9].*) echo "0.16"; exit 0 ;;
    esac
fi

# 3. Default to current release
echo "0.16"
