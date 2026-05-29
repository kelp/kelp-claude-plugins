# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code)
when working with code in this repository.

## What This Repo Is

A Claude Code plugin marketplace containing these plugins:

- **zig-claude-kit** -- corrective context for Zig 0.15.x
  that fixes Claude's outdated training data
- **tiger-style** -- TigerBeetle's Tiger Style methodology
  for Zig (assertions, bounded loops, static memory,
  snake_case naming, 70-line / 100-col limits)
- **tdd-pipeline** -- language-agnostic TDD pipeline with
  seven agents across separate stages
- **cross-review** -- multi-model code review with
  cross-validation using Claude and GPT-5.5
- **knowledge-forge** -- cross-session routing and
  capture for a three-layer personal knowledge base

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
    scripts/                       # eval suite + session-start
    docs/                          # fragment, breaking changes ref
  tiger-style/
    .claude-plugin/plugin.json     # manifest (version here)
    skills/                        # tiger-init, tiger-patterns, tiger-check
    hooks/hooks.json               # SessionStart hook
    scripts/                       # session-start
    docs/                          # fragment, reference doc
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
  knowledge-forge/
    .claude-plugin/plugin.json     # manifest (version here)
    skills/                        # kb-capture, kb-ingest,
                                   #   kb-research-policy
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
make eval                              # test all models
make eval-model MODEL=claude-haiku-4-5 # test one model
make compile-test MODEL=claude-sonnet-4-6
make audit                             # probe current Zig
```

Requires `ANTHROPIC_API_KEY` and `uv`.

## Writing Style

Follow Strunk & White: omit needless words, use active
voice, make definite assertions. Wrap markdown at 78
characters.
