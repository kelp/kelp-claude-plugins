---
description: >
  Add Zig training corrections to this project's CLAUDE.md.
  Detects whether the project targets Zig 0.15.x or 0.16.x and
  appends the matching corrections. Run this in any Zig project
  to fix Claude's outdated patterns for I/O, ArrayList, format
  strings, build.zig, and (for 0.16) the new Io interface,
  std.fs -> std.Io move, and indexOf -> find rename.
user-invocable: true
---

# /zig-init

Add Zig training corrections to this project's CLAUDE.md. The
plugin supports both 0.15.x and 0.16.x; this skill detects the
target version and appends the matching fragment.

## Procedure

### 1. Detect Zig version

Run the detection helper:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/detect-zig-version.sh
```

It prints `0.15` or `0.16` based on (in order): the project's
`build.zig.zon` `.minimum_zig_version` field, then `zig
version` if zig is on PATH, then a default of `0.16`.

Capture the output as `$VERSION`.

### 2. Read the version-specific fragment

Read the file at:

```
${CLAUDE_PLUGIN_ROOT}/docs/$VERSION/claude-md-fragment.md
```

This contains the corrections formatted as a CLAUDE.md section
matched to the detected version. If the file is missing,
report the error to the user and stop -- do not proceed.

### 3. Check current CLAUDE.md

Each fragment opens with a version-specific marker heading:

- `0.15` fragment: `## Zig 0.15.x Training Corrections`
- `0.16` fragment: `## Zig 0.16.x Training Corrections`

Branch on the detected version:

- If no `CLAUDE.md` exists in the project root, create one
  with just a `# CLAUDE.md` header followed by the fragment
  content.
- If `CLAUDE.md` already contains the version-specific marker,
  report "Zig $VERSION.x corrections already present" and stop.
- If `CLAUDE.md` contains the *other* version's marker (e.g.
  the project was previously targeting 0.15 and is now 0.16),
  report "CLAUDE.md has corrections for the other Zig version
  ($OTHER); manual review needed before swapping" and stop —
  do not silently overwrite.
- Otherwise append the fragment content to the end of the
  file. Ensure a blank line separates the existing content
  from the fragment.

### 4. Report result

Tell the user what you did:
- "Created CLAUDE.md with Zig $VERSION.x corrections"
- "Added Zig $VERSION.x corrections to existing CLAUDE.md"
- "Zig $VERSION.x corrections already present in CLAUDE.md"
- "CLAUDE.md targets the other Zig version; manual review
  needed before swapping" (with current marker named)
