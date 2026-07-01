---
description: >
  Add TigerBeetle's Tiger Style guidance to this project's
  CLAUDE.md. Run this in any Zig project to apply Tiger
  Style's rules on assertions, bounded loops, static
  memory, naming, function shape, comments, and
  formatting.
user-invocable: true
---

# /tiger-init

Add Tiger Style guidance to this project's CLAUDE.md.

## Procedure

### 1. Read the Tiger Style fragment

Read the file at
`${CLAUDE_PLUGIN_ROOT}/docs/claude-md-fragment.md`.
This contains Tiger Style rules formatted as a CLAUDE.md
section. If the file is missing, report the error and
stop -- do not proceed without it.

### 2. Check current CLAUDE.md

- If no `CLAUDE.md` exists in the project root, create
  one with just a `# CLAUDE.md` header followed by the
  fragment content.
- If `CLAUDE.md` exists, check if it already contains the
  heading `## Tiger Style`. If so, report "Tiger Style
  guidance already present" and stop.
- If `CLAUDE.md` exists but lacks that heading, append
  the fragment content to the end of the file, separated
  from the existing content by a blank line.

### 3. Report result

Tell the user what you did:
- "Created CLAUDE.md with Tiger Style guidance"
- "Added Tiger Style guidance to existing CLAUDE.md"
- "Tiger Style guidance already present in CLAUDE.md"
