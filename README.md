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
build.zig, format strings, ArrayList, BoundedArray,
usingnamespace, signed division, tokenize, process
args, JSON, for-loop index, and O_APPEND.

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

### tdd-pipeline

Language-agnostic TDD pipeline with test-first agents,
review loops, and verify gates. Enforces a 7-stage
pipeline: write tests, review, red gate, implement,
verify, review code, integrate.

```bash
/plugin install tdd-pipeline@kelp-claude-plugins
```

Run `/tdd-init` in your project to add a configuration
template to CLAUDE.md. Then invoke `/tdd-orchestrate`
with a module name to drive the full pipeline.

**Skills:**
- `/tdd-pipeline:tdd-orchestrate` -- Run the 7-stage
  TDD pipeline for a module
- `/tdd-pipeline:tdd-init` -- Add pipeline config
  template to project CLAUDE.md

Composes with language plugins like zig-claude-kit.
CLAUDE.md is the integration point -- no coupling
between plugins at the code level.

See [plugins/tdd-pipeline/](plugins/tdd-pipeline/)
for full documentation.

## Versioning

Plugins use semver. Versions are set in each plugin's
`plugin.json` only -- not in `marketplace.json`.
Claude Code uses the version for cache invalidation;
bumping it is required for users to see changes.

Both plugins currently use 0.x versions (pre-stable).
Earlier zig-claude-kit releases used 1.x versions
in error; reset to 0.2.0 to follow semver correctly.

## License

Public domain. Use however you like.
