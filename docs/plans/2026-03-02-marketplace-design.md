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
│       ├── hooks/
│       │   └── hooks.json
│       ├── scripts/
│       │   ├── session-start.sh
│       │   ├── zig-knowledge-audit.sh
│       │   ├── zig-knowledge-eval.py
│       │   ├── zig-knowledge-prompts.md
│       │   └── zig-knowledge-test.sh
│       ├── skills/
│       │   ├── zig-patterns/
│       │   │   └── SKILL.md
│       │   ├── zig-check/
│       │   │   └── SKILL.md
│       │   └── zig-init/
│       │       └── SKILL.md
│       ├── docs/
│       │   ├── ZIG_BREAKING_CHANGES.md
│       │   └── claude-md-fragment.md
│       ├── probes/
│       │   ├── claude-opus-4-6/
│       │   └── claude-sonnet-4-6/
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

## plugin.json

```json
{
  "name": "zig-claude-kit",
  "description": "Corrective context for Zig 0.15.x that fixes Claude's outdated training data.",
  "version": "1.0.0",
  "author": {
    "name": "Travis Cole"
  },
  "homepage": "https://github.com/kelp/kelp-claude-plugins",
  "repository": "https://github.com/kelp/kelp-claude-plugins",
  "hooks": "./hooks/hooks.json"
}
```

## Correction Delivery

The plugin delivers Zig corrections through two mechanisms:

### SessionStart Hook

A hook script runs at session start and:

1. Checks if this is a Zig project (looks for `build.zig`
   or `*.zig` files)
2. Checks if the project's CLAUDE.md already contains the
   corrections (looks for "Writergate" marker)
3. If corrections are missing, injects context telling
   Claude to run `/zig-init`

```bash
#!/bin/bash
# scripts/session-start.sh
if [ ! -f "build.zig" ]; then exit 0; fi
if grep -q "Writergate" CLAUDE.md 2>/dev/null; then exit 0; fi

echo "This is a Zig project missing Zig 0.15.x corrections."
echo "Run /zig-init to add them to this project's CLAUDE.md."
exit 0
```

### /zig-init Skill

A skill that adds Zig 0.15.x corrections to the project's
CLAUDE.md. It reads `docs/claude-md-fragment.md` from the
plugin directory (`${CLAUDE_PLUGIN_ROOT}`) and:

- If no CLAUDE.md exists, creates one with the fragment
- If CLAUDE.md exists, appends the fragment

The fragment contains the 6 pattern corrections and code
examples — the essential content from the current CLAUDE.md,
formatted as a section that can be appended.

### docs/claude-md-fragment.md

A standalone section of CLAUDE.md content containing the
Zig 0.15.x corrections. Designed to be appended to any
existing CLAUDE.md. The current repo-root CLAUDE.md becomes
this fragment (the plugin itself no longer needs a CLAUDE.md
at its root).

## Install Flow

```bash
/plugin marketplace add kelp/kelp-claude-plugins
/plugin install zig-claude-kit@kelp-claude-plugins
```

## What Moves Where

| Current path | New path |
|---|---|
| `CLAUDE.md` | Becomes `plugins/zig-claude-kit/docs/claude-md-fragment.md` |
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
| `plugins/zig-claude-kit/hooks/hooks.json` | SessionStart hook config |
| `plugins/zig-claude-kit/scripts/session-start.sh` | Detects Zig projects, prompts /zig-init |
| `plugins/zig-claude-kit/skills/zig-init/SKILL.md` | Adds corrections to project CLAUDE.md |
| `plugins/zig-claude-kit/docs/claude-md-fragment.md` | CLAUDE.md content to inject |

## Files Removed

| Path | Reason |
|---|---|
| `CLAUDE.md` (root) | Content moves to `claude-md-fragment.md` |
| `.claude/settings.local.json` | Recreate at root if needed |

## Future Plugins

Add new plugins as `plugins/<name>/` with their own
`.claude-plugin/plugin.json`, skills, etc. Add an entry
to `marketplace.json`.
