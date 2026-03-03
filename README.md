# kelp-claude-plugins

Claude Code plugins by kelp.

## Installation

Add this marketplace to Claude Code:

```bash
/plugin marketplace add kelp/kelp-claude-plugins
```

## Available Plugins

### zig-claude-kit

Corrective context for Zig 0.15.x that fixes Claude's
outdated training data. Covers I/O (Writergate),
build.zig, format strings, ArrayList, BoundedArray, and
usingnamespace.

```bash
/plugin install zig-claude-kit@kelp-claude-plugins
```

Once installed, open any Zig project. The plugin detects
it at session start and prompts you to run `/zig-init`,
which adds the corrections to your project's CLAUDE.md.

**Skills:**
- `/zig-claude-kit:zig-patterns` -- Quick reference for
  correct Zig 0.15.x patterns
- `/zig-claude-kit:zig-check` -- Audit Zig files for
  common mistakes
- `/zig-claude-kit:zig-init` -- Add corrections to
  project CLAUDE.md

See [plugins/zig-claude-kit/](plugins/zig-claude-kit/)
for full documentation.

## License

Public domain. Use however you like.
