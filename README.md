# kelp-claude-plugins

Two plugins that make Claude Code write correct code:
one enforces TDD, the other fixes Zig 0.15.x.

## Install

```bash
/plugin marketplace add kelp/kelp-claude-plugins
```

## Plugins

### zig-claude-kit

Claude generates broken Zig 0.15.x code for 12 specific
patterns. This plugin corrects them by appending the right
patterns to your project's CLAUDE.md so every agent
reads them.

```bash
/plugin install zig-claude-kit@kelp-claude-plugins
```

Open a Zig project. The plugin detects Zig source files
and prompts you to run `/zig-init`. From that point,
Claude writes correct Zig.

**Commands:**
- `/zig-init` -- inject corrections into CLAUDE.md
- `/zig-patterns` -- quick reference with code examples
- `/zig-check` -- audit files for outdated API usage

### tdd-pipeline

Claude skips tests, writes stubs, and reviews its own
work. This plugin stops that. It splits every module
into seven stages across separate agents -- no single
agent both writes and reviews code.

```bash
/plugin install tdd-pipeline@kelp-claude-plugins
```

Run `/tdd-init` to configure your project, then
`/tdd-orchestrate parser` to build a module.

**The pipeline:**

```
1. Test Writer    write tests + type stubs (RED)
2. Test Reviewer  review tests, fix loop
3. Red Gate       confirm all tests fail against stubs
4. Implementer    write code to pass tests (GREEN)
5. Verify Gate    tests pass, no stubs, lint clean
6. Code Reviewer  review implementation, fix loop
7. Integrate      update build files, full tests, commit
```

The orchestrator -- your main Claude session --
dispatches agents and never writes code. Each agent receives a role skill that constrains
what it can touch. Language-specific context comes from
CLAUDE.md, not the plugin -- so the pipeline works with
any language.

## Composition

CLAUDE.md connects these plugins:

1. `zig-claude-kit` appends language corrections
2. `tdd-pipeline` reads test commands and file patterns

## License

Public domain.
