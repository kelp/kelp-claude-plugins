---
description: >
  Add Zig training corrections to this project's CLAUDE.md.
  Auto-detects whether the project targets Zig 0.15.x or 0.16
  (from build.zig.zon's minimum_zig_version, falling back to
  `zig version`) and injects the matching corrections.
---

# /zig-init

Add Zig training corrections to this project's CLAUDE.md.

## Procedure

### 1. Detect the project's Zig version

Run `${CLAUDE_PLUGIN_ROOT}/scripts/detect-zig-version.sh` from
the project root. It prints either `0.15` or `0.16`. The script
defaults to `0.16` when nothing is detectable.

### 2. Read the matching corrections fragment

Use the detected version to pick the fragment:

- `0.15` -> `${CLAUDE_PLUGIN_ROOT}/docs/claude-md-fragment-0.15.md`
- `0.16` -> `${CLAUDE_PLUGIN_ROOT}/docs/claude-md-fragment-0.16.md`

### 3. Check current CLAUDE.md

- If no `CLAUDE.md` exists in the project root, create one with
  just a `# CLAUDE.md` header followed by the fragment content.
- If `CLAUDE.md` exists, check if it already contains
  "Writergate". If so, report "Zig corrections already present"
  and stop. (Note: this matches either version's fragment; the
  user can manually swap fragments if their project's target
  version changed.)
- If `CLAUDE.md` exists but lacks the corrections, append the
  fragment content to the end of the file.

### 4. Report result

Tell the user what you did and which version was detected:

- "Created CLAUDE.md with Zig 0.16.x corrections"
- "Added Zig 0.15.x corrections to existing CLAUDE.md"
- "Zig corrections already present in CLAUDE.md"

If detection fell back to the default (0.16) because no
`build.zig.zon` was present and `zig` was not installed,
mention that the user can re-run `/zig-init` once they've set
`minimum_zig_version` in `build.zig.zon`.
