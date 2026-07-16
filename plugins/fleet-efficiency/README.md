# fleet-efficiency

Claude Code plugin that teaches token-efficient patterns
for fanning out many subagents.

## What it does

A single auto-discovered skill, matched via its
description whenever a session is about to launch 3+
parallel agents, write a Workflow script, or run an
audit, migration, or multi-stage pipeline across many
files. It carries three rule sets:

**Context handoff** -- scout once and brief many instead
of letting N agents rediscover the repo; paste relevant
excerpts into prompts instead of pointing at files; hand
structured artifacts forward between pipeline stages;
continue an existing agent rather than respawning one.

**Prompt caching** -- keep the shared brief byte-identical
at the top of every fleet prompt, and keep prompts
byte-stable (no timestamps or run ids) so Workflow resume
and cross-agent prompt caching hold.

**Model tiers** -- every agent dispatch names its model
explicitly; sonnet for mechanical work, opus for ordinary
implementation and review, fable budgeted for the hardest
judgment calls.

## Installation

```
/plugin marketplace add kelp/kelp-claude-plugins
/plugin install fleet-efficiency@kelp-claude-plugins
```

No configuration. The skill is model-invoked; there are
no slash commands, hooks, or agents.
