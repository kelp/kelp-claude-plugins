# tdd-pipeline

Language-agnostic TDD pipeline for Claude Code with
test-first agents, review loops, and verify gates.

## What It Does

Enforces a 7-stage TDD pipeline per module:

```
1. TEST WRITER    -> tests + type stubs (compile, FAIL)
2. TEST REVIEWER  -> review tests, fix loop
3. RED GATE       -> confirm ALL tests fail against stubs
4. IMPLEMENTER    -> write code to pass tests (GREEN)
5. VERIFY GATE    -> tests pass, no stubs, lint clean
6. CODE REVIEWER  -> review implementation, fix loop
7. INTEGRATE      -> update build files, full tests, commit
```

The main context acts as a pure dispatcher and never
writes code directly. Each stage uses a dedicated agent
with a specific role skill.

## Installation

```
claude plugin add kelp/kelp-claude-plugins \
  --plugin tdd-pipeline
```

## Setup

1. Run `/tdd-init` in your project to add a
   configuration template to CLAUDE.md
2. Fill in the placeholder values: test commands,
   file patterns, lint rules

## Usage

Invoke `/tdd-orchestrate` with a module name and
behavior list:

```
/tdd-orchestrate
Module: parser
Behaviors:
1. Parses valid input into a struct
2. Returns error on malformed input
3. Handles empty input gracefully
```

The orchestrator drives all 7 stages automatically,
dispatching agents for each role.

## Composition

This plugin defines **process** (roles, rules, flow).
Your project's CLAUDE.md defines **project specifics**
(test commands, file patterns, lint rules). Language
plugins inject corrections into CLAUDE.md. No coupling
between plugins at the code level.

Example with Zig:
1. Install `zig-claude-kit` and run `/zig-init`
2. Install `tdd-pipeline` and run `/tdd-init`
3. Fill in the TDD config template
4. Run `/tdd-orchestrate` for each module

## Skills

| Skill | Type | Purpose |
|-------|------|---------|
| tdd-orchestrate | user-invocable | 7-stage pipeline entry point |
| tdd-init | user-invocable | Add config template to CLAUDE.md |
| test-writer | agent role | Write tests and type stubs |
| test-reviewer | agent role | Review tests |
| implementer | agent role | Write implementation |
| code-reviewer | agent role | Review implementation |
| agent-briefing | agent context | Common agent rules |

## Documentation

- [Methodology](docs/methodology.md) -- full pipeline
  reference with RED gate, verify gate, fix loops
- [CLAUDE.md Fragment](docs/claude-md-fragment.md) --
  configuration template appended by /tdd-init
