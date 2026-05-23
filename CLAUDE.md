# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code)
when working with code in this repository.

## What This Repo Is

A Claude Code plugin marketplace containing three plugins:

- **zig-claude-kit** -- corrective context for Zig 0.15.x and
  0.16 that fixes Claude's outdated training data;
  auto-detects target from build.zig.zon
- **tdd-pipeline** -- language-agnostic TDD pipeline with
  seven agents across separate stages
- **cross-review** -- multi-model code review with
  cross-validation using Claude and GPT-5.4

Users install via `/plugin marketplace add kelp/kelp-claude-plugins`,
then `/plugin install <name>@kelp-claude-plugins`.

## Repository Structure

```
.claude-plugin/marketplace.json    # plugin registry
plugins/
  zig-claude-kit/
    .claude-plugin/plugin.json     # manifest (version here)
    skills/                        # zig-init, zig-patterns, zig-check
    hooks/hooks.json               # SessionStart hook
    scripts/                       # eval suite, audit-0.15/0.16,
                                   #   session-start, detect-zig-version
    docs/                          # claude-md-fragment-{0.15,0.16}.md,
                                   #   ZIG_BREAKING_CHANGES-{0.15,0.16}.md
  tdd-pipeline/
    .claude-plugin/plugin.json     # manifest (version here)
    skills/                        # tdd-orchestrate, tdd-init
    agents/                        # test-writer, test-reviewer,
                                   #   implementer, code-reviewer
    docs/                          # fragment, methodology ref
  cross-review/
    .claude-plugin/plugin.json     # manifest (version here)
    skills/cross-review/           # orchestrator skill
    agents/                        # reviewer, validator
    docs/                          # fragment
```

## Key Conventions

### Plugin Variables

Skills use these Claude Code plugin variables:
- `${CLAUDE_PLUGIN_ROOT}` -- absolute path to the plugin
  directory at runtime
- `$0`, `$1`, `$ARGUMENTS` -- user arguments passed to
  user-invocable skills

### Version Management

Version lives only in each plugin's
`.claude-plugin/plugin.json`. The marketplace.json must
NOT contain version fields -- Claude Code silently
overrides them from plugin.json anyway.

All plugins use 0.x semver (pre-stable).

### SKILL.md Format

Skills use YAML frontmatter with these fields:
- `name`, `description` -- required
- `user-invocable: true` -- for slash commands
- Agent role skills omit `user-invocable` (injected into
  agent prompts by the orchestrator, not called directly)

### Composition Model

CLAUDE.md is the integration point between plugins.
Language plugins (zig-claude-kit) append corrections.
Process plugins (tdd-pipeline) read test commands and
file patterns. No code-level coupling between plugins.

## Zig Plugin Eval Suite

Run from `plugins/zig-claude-kit/`:

```bash
make audit                             # auto-detect Zig version
make audit-0.15                        # validate 0.15.x claims
make audit-0.16                        # validate 0.16 claims

make eval TARGET=0.16                  # blind-test default models
make eval-model MODEL=claude-haiku-4-5 TARGET=0.16
make compile-test MODEL=claude-sonnet-4-6 TARGET=0.16
```

`make eval` requires `ANTHROPIC_API_KEY` and `uv`; `make audit`
requires `zig` on `PATH`. The `TARGET` variable labels output
probe directories; what actually validates the code is the
locally installed Zig.

## Writing Style

Follow Strunk & White: omit needless words, use active
voice, make definite assertions. Wrap markdown at 78
characters.
