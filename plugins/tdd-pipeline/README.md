# tdd-pipeline

Claude skips tests, reviews its own work, and writes
stubs that pass. This plugin enforces test-first
discipline with seven agents across separate stages.

## How It Works

Seven agents, seven stages. No single agent both writes
and reviews code. The orchestrator -- your main Claude
session -- dispatches agents and reads only CLAUDE.md.

```
1. Test Writer    write tests + type stubs (RED)
2. Test Reviewer  review tests, fix loop
3. Red Gate       confirm all tests fail against stubs
4. Implementer    write code to pass tests (GREEN)
5. Verify Gate    tests pass, no stubs, lint clean
6. Code Reviewer  review implementation, fix loop
7. Integrate      update build files, full tests, commit
```

The RED gate catches a common failure: stubs that
contain real logic. Tests against such stubs always
pass, proving nothing. Every test must fail before
implementation begins.

## Install

```bash
/plugin marketplace add kelp/kelp-claude-plugins
/plugin install tdd-pipeline@kelp-claude-plugins
```

## Setup

1. Run `/tdd-init` to add a configuration template to
   your project's CLAUDE.md
2. Fill in test commands, file patterns, and lint rules

## Use

```
/tdd-orchestrate parser
```

The orchestrator reads your CLAUDE.md for project
specifics, then drives all seven stages. If a reviewer
rejects code three times, it escalates to you.

## Composition

This plugin defines the process. Your CLAUDE.md defines
project specifics, and language plugins append
corrections.

Example with Zig:
1. Install `zig-claude-kit`, run `/zig-init`
2. Install `tdd-pipeline`, run `/tdd-init`
3. Fill in test commands and file patterns
4. Run `/tdd-orchestrate` for each module

CLAUDE.md is the only integration point between plugins.

## Skills

**User-invocable:**
- `tdd-orchestrate` -- drive the 7-stage pipeline
- `tdd-init` -- add config template to CLAUDE.md

**Agent roles** (injected into sub-agent prompts):
- `test-writer` -- write tests and type stubs
- `test-reviewer` -- review tests for correctness
- `implementer` -- write implementation code
- `code-reviewer` -- review implementation
- `agent-briefing` -- common rules for all agents

## Reference

- [Methodology](docs/methodology.md) -- pipeline
  stages, gates, fix loops
- [CLAUDE.md Fragment](docs/claude-md-fragment.md) --
  configuration template
