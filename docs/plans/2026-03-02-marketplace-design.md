# Marketplace Restructure Design

## Goal

Convert `kelp/zig-claude-kit` into `kelp/kelp-claude-plugins`,
a Claude Code plugin marketplace. The zig-claude-kit plugin
becomes the first plugin in the marketplace. Future plugins
go alongside it.

## Approach

Monorepo marketplace (Anthropic-style). Plugin code lives
inline under `plugins/`. The marketplace catalog references
plugins by relative path.

## Repo Changes

Rename GitHub repo from `zig-claude-kit` to
`kelp-claude-plugins`.

## Target Structure

```
kelp-claude-plugins/
├── .claude-plugin/
│   └── marketplace.json
├── plugins/
│   └── zig-claude-kit/
│       ├── .claude-plugin/
│       │   └── plugin.json
│       ├── skills/
│       │   ├── zig-patterns/
│       │   │   └── SKILL.md
│       │   └── zig-check/
│       │       └── SKILL.md
│       ├── docs/
│       │   └── ZIG_BREAKING_CHANGES.md
│       ├── scripts/
│       │   ├── zig-knowledge-audit.sh
│       │   ├── zig-knowledge-eval.py
│       │   ├── zig-knowledge-prompts.md
│       │   └── zig-knowledge-test.sh
│       ├── probes/
│       │   ├── claude-opus-4-6/
│       │   └── claude-sonnet-4-6/
│       ├── CLAUDE.md
│       ├── README.md
│       └── justfile
├── README.md
├── .gitignore
└── .claude/
    └── settings.local.json
```

## marketplace.json

```json
{
  "name": "kelp-claude-plugins",
  "owner": {
    "name": "Travis Cole",
    "email": "kelp@plek.org"
  },
  "metadata": {
    "description": "Claude Code plugins by kelp",
    "version": "1.0.0"
  },
  "plugins": [
    {
      "name": "zig-claude-kit",
      "source": "./plugins/zig-claude-kit",
      "description": "Corrective context for Zig 0.15.x that fixes Claude's outdated training data. Covers I/O (Writergate), build.zig, format strings, ArrayList, BoundedArray, and usingnamespace.",
      "version": "1.0.0",
      "strict": true
    }
  ]
}
```

## plugin.json (unchanged content, moved location)

```json
{
  "name": "zig-claude-kit",
  "description": "Corrective context for Zig 0.15.x that fixes Claude's outdated training data.",
  "version": "1.0.0",
  "author": {
    "name": "Travis Cole"
  },
  "homepage": "https://github.com/kelp/kelp-claude-plugins",
  "repository": "https://github.com/kelp/kelp-claude-plugins"
}
```

## Install Flow

```bash
/plugin marketplace add kelp/kelp-claude-plugins
/plugin install zig-claude-kit@kelp-claude-plugins
```

## What Moves Where

| Current path | New path |
|---|---|
| `CLAUDE.md` | `plugins/zig-claude-kit/CLAUDE.md` |
| `README.md` | `plugins/zig-claude-kit/README.md` |
| `docs/` | `plugins/zig-claude-kit/docs/` |
| `skills/` | `plugins/zig-claude-kit/skills/` |
| `scripts/` | `plugins/zig-claude-kit/scripts/` |
| `probes/` | `plugins/zig-claude-kit/probes/` |
| `justfile` | `plugins/zig-claude-kit/justfile` |
| `.claude-plugin/plugin.json` | `plugins/zig-claude-kit/.claude-plugin/plugin.json` |

## New Files

| Path | Purpose |
|---|---|
| `.claude-plugin/marketplace.json` | Marketplace catalog |
| `README.md` | Marketplace landing page |

## Files Removed

| Path | Reason |
|---|---|
| `.claude/settings.local.json` | Recreate at root if needed |

## Future Plugins

Add new plugins as `plugins/<name>/` with their own
`.claude-plugin/plugin.json`, skills, etc. Add an entry
to `marketplace.json`.
