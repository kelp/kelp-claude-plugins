---
name: tdd-init
description: >
  Add TDD pipeline configuration template to this
  project's CLAUDE.md. Run this to set up the pipeline
  for a new project.
user-invocable: true
---

# /tdd-init

Add TDD pipeline configuration to this project's
CLAUDE.md.

## Procedure

### 1. Read the configuration fragment

Read the file at
`${CLAUDE_PLUGIN_ROOT}/docs/claude-md-fragment.md`.
This contains the TDD pipeline configuration template
formatted as a CLAUDE.md section.

### 2. Check current CLAUDE.md

- If no `CLAUDE.md` exists in the project root, create
  one with just a `# CLAUDE.md` header followed by the
  fragment content.
- If `CLAUDE.md` exists, check if it already contains
  "TDD Pipeline Configuration". If so, report "TDD
  pipeline configuration already present" and stop.
- If `CLAUDE.md` exists but lacks the configuration,
  append the fragment content to the end of the file.

### 3. Report result

Tell the user what you did:
- "Created CLAUDE.md with TDD pipeline configuration"
- "Added TDD pipeline configuration to existing
  CLAUDE.md"
- "TDD pipeline configuration already present in
  CLAUDE.md"

### 4. Next steps

Tell the user to fill in the template values:
- Test command for individual modules
- Source and test file path patterns
- Build integration steps
- Full test and lint commands
- Any language-specific agent context
