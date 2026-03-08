---
name: agent-briefing
description: >
  Standard briefing for coding agents. Covers file rules,
  shell rules, quality bar, and directive to read CLAUDE.md
  for project-specific context.
user-invocable: false
---

# Agent Briefing

Read this entire document before writing any code.

## File Rules

Write ONLY the files your role permits:
- **Test writers**: test files (and minimal type stubs)
- **Implementers**: source files only

Do NOT modify build files or configuration files.
Do NOT commit -- the orchestrator handles commits.

Check the project's CLAUDE.md for exact file paths
and patterns (e.g. `src/{module}.py`,
`tests/test_{module}.py`).

## Quality Bar

Complete ALL listed behaviors. Partial work will be
rejected.
- **Test writers**: one test per behavior minimum,
  stubs return trivial values only
- **Implementers**: all tests must pass, no shortcuts

Every public function must have at least one test
exercising it.

## Test Command

Read the project's CLAUDE.md for the test command.
Run it exactly as specified.

## Shell Rules

Run commands exactly as shown. Do NOT append shell
syntax like `2>&1`, `; echo "EXIT: $?"`, or pipe
redirections. The Bash tool already captures stdout,
stderr, and exit codes.

## Language-Specific Context

Read the project's CLAUDE.md for language-specific
corrections, lint rules, and coding standards. If
a language plugin has injected corrections (e.g.
API changes or lint rules), they will appear there.
