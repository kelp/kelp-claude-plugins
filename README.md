# kelp-claude-plugins

Claude Code plugins by kelp:

- **zig-claude-kit** -- fixes Claude's broken Zig 0.15.x
- **tiger-style** -- applies TigerBeetle's Tiger Style to
  Zig projects
- **tdd-pipeline** -- enforces TDD across separate agents
- **cross-review** -- gets a second opinion from GPT-5.5
- **knowledge-forge** -- captures notes and routes
  retrieval for a personal knowledge base

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

### tiger-style

TigerBeetle's [Tiger Style][tiger] is an opinionated
methodology for safety-critical Zig: minimum two
assertions per function, no recursion, static memory
after init, snake_case with unit suffixes, 70-line
function limit, 100-column line limit. This plugin
auto-detects Zig projects and offers to apply Tiger
Style to them by appending the rules to your project's
CLAUDE.md.

[tiger]: https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md

```bash
/plugin install tiger-style@kelp-claude-plugins
```

Open a Zig project. The plugin detects Zig source files
and prompts you to run `/tiger-init`. From that point,
Claude follows Tiger Style in that project. Uninstall
the plugin if a particular Zig project should not follow
Tiger Style -- the SessionStart hook prompts in every
Zig project until then.

**Commands:**
- `/tiger-init` -- inject Tiger Style into CLAUDE.md
- `/tiger-patterns` -- quick reference with code
  examples (auto-discovered)
- `/tiger-check [file]` -- audit files for mechanical
  violations (fn > 70 lines, line > 100 cols, `usize`,
  recursion, compound asserts, unbounded `while (true)`)

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

### cross-review

A single model reviewing its own work misses bugs it
would catch in someone else's. This plugin runs
independent Claude and GPT-5.5 reviews, has each model
validate the other's findings against the actual code,
and merges the result into one prioritized fix list.

```bash
/plugin install cross-review@kelp-claude-plugins
```

Run `/cross-review` on uncommitted changes, or pass a
scope: `/cross-review src/parser.zig` or `/cross-review
last 2 commits`. Disputed findings are separated from
confirmed ones so humans can triage them.

**Flags:**
- `--quick` -- skip cross-validation, merge raw findings
- `--reconcile` -- let each model defend its disputed
  findings in one follow-up round

**Requirements:**
- [Codex CLI](https://github.com/openai/codex),
  authenticated for GPT-5.5 access
- [codex-plugin-cc](https://github.com/openai/codex-plugin-cc),
  OpenAI's Claude Code plugin that bridges Codex to
  Claude Code. It installs via its `openai-codex`
  marketplace and ships the companion script we call.
  By default the plugin looks for that script at
  `$HOME/.claude/plugins/marketplaces/openai-codex/plugins/codex/scripts/codex-companion.mjs`.
  If you installed codex-plugin-cc elsewhere, set
  `codex-script:` in your project CLAUDE.md to the
  actual path — for security, the resolved path must
  be under `$HOME/.claude/plugins/`.
- Node.js on `PATH` to run the companion script

Without these, `/cross-review` falls back to claude-only
mode and runs a single-model review.

### knowledge-forge

Cross-session routing and capture for a three-layer
personal knowledge base. An auto-discovered policy skill
teaches Claude to check the knowledge base index first
before answering retrieval questions. Two slash commands
write into the base.

```bash
/plugin install knowledge-forge@kelp-claude-plugins
```

**Commands:**
- `/kb-capture` -- file the current conversation,
  source, or synthesis into the right wiki bucket with
  correct frontmatter and citations
- `/kb-ingest <url>` -- crawl an external documentation
  site into the knowledge base as a doc pack and source
  note

This plugin is built around a specific personal-KB
layout. Useful as a reference for plugins that integrate
with a per-user knowledge store; adapt the paths and
bucket conventions if you adopt it.

## Composition

CLAUDE.md connects these plugins:

1. `zig-claude-kit` appends Zig 0.15.x corrections
2. `tiger-style` appends Tiger Style guidance
3. `tdd-pipeline` reads test commands and file patterns
4. `cross-review` reads the codex script path and
   optional review focus
5. `knowledge-forge` reads the `knowledge-base:` path
   from the active project CLAUDE.md

## License

Public domain.
