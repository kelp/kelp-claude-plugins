#!/usr/bin/env bash
# Resolve the knowledge base path for knowledge-forge skills.
# Prints the resolved absolute path on stdout on success.
# On failure, prints an error to stderr and exits non-zero.
set -euo pipefail

kb_path=""
if [ -f CLAUDE.md ]; then
  raw=$(grep -E "^knowledge-base:" CLAUDE.md | head -1 \
    | sed 's/^knowledge-base://; s/^[[:space:]]*//; s/[[:space:]]*$//')
  if [ -n "$raw" ]; then
    # Expand ~ or $HOME prefix only -- never eval
    # untrusted CLAUDE.md content
    case "$raw" in
      '~'|'~/'*) kb_path="$HOME${raw#\~}" ;;
      '$HOME'*)  kb_path="$HOME${raw#\$HOME}" ;;
      *)         kb_path="$raw" ;;
    esac
  fi
fi
if [ -z "$kb_path" ]; then
  kb_path="$HOME/code/knowledge"
fi
kb_path=$(realpath -- "$kb_path" 2>/dev/null) || {
  echo "knowledge-forge: cannot resolve KB path" >&2
  exit 1
}
case "$kb_path" in
  *$'\n'*|*$'\r'*|*\\*)
    echo "knowledge-forge: invalid characters in KB path" >&2
    exit 1 ;;
esac
if [ ! -f "$kb_path/justfile" ] || [ ! -d "$kb_path/index" ]; then
  echo "knowledge-forge: $kb_path is not a knowledge base" >&2
  exit 1
fi

echo "$kb_path"
