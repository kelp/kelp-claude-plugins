---
description: >
  Add Zig 0.15.x training corrections to this project's
  CLAUDE.md. Run this in any Zig project to fix Claude's
  outdated patterns for I/O, ArrayList, format strings,
  build.zig, BoundedArray, and usingnamespace.
---

# /zig-init

Add Zig 0.15.x corrections to this project's CLAUDE.md.

## Procedure

### 1. Read the corrections fragment

Read the file at
`${CLAUDE_PLUGIN_ROOT}/docs/claude-md-fragment.md`.
This contains the Zig 0.15.x training corrections
formatted as a CLAUDE.md section.

### 2. Check current CLAUDE.md

- If no `CLAUDE.md` exists in the project root, create
  one with just a `# CLAUDE.md` header followed by the
  fragment content.
- If `CLAUDE.md` exists, check if it already contains
  "Writergate". If so, report "Zig corrections already
  present" and stop.
- If `CLAUDE.md` exists but lacks the corrections,
  append the fragment content to the end of the file.

### 3. Report result

Tell the user what you did:
- "Created CLAUDE.md with Zig 0.15.x corrections"
- "Added Zig 0.15.x corrections to existing CLAUDE.md"
- "Zig corrections already present in CLAUDE.md"
