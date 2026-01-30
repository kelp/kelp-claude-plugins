# zig-claude-kit

Corrective context files that fix Claude's outdated Zig training
for 0.15.x projects.

## Problem

Claude (Opus 4.5, Sonnet 4.5) consistently generates broken Zig
code for 6 specific patterns. Blind testing confirmed these are
baked into the models' training data and persist across fresh
conversations with no project context.

## What's Covered

The 6 blind spots, verified by compiler probes:

1. **Writergate** -- `std.io.getStdOut()`/`getStdErr()` removed;
   must use buffered writer pattern
2. **build.zig** -- `.root_source_file` moved inside
   `.root_module = b.createModule(...)`
3. **Format methods** -- signature changed to
   `(self, writer: *std.Io.Writer)`; `{}` requires `{f}`
4. **usingnamespace** -- removed from language entirely
5. **BoundedArray** -- removed; use
   `ArrayListUnmanaged.initBuffer`
6. **ArrayList.init()** -- managed API removed; use
   `ArrayListUnmanaged{}` with allocator per call

## Usage

Copy these files into your Zig project:

```
CLAUDE.md                         # Core training corrections
docs/ZIG_BREAKING_CHANGES.md      # Full reference with code
.claude/skills/zig-patterns/      # I/O, ArrayList, format patterns
.claude/skills/zig-check/         # Audit checklist skill
```

Or reference from your project's CLAUDE.md:

```markdown
## Zig Training Corrections
See zig-claude-kit for Zig 0.15.x training overrides.
Read `docs/ZIG_BREAKING_CHANGES.md` before writing any Zig code.
```

## Re-testing After Model or Zig Upgrades

The `scripts/` directory contains tools to re-validate whether
these corrections are still needed:

```bash
# Run compiler probes against current Zig version
./scripts/zig-knowledge-audit.sh

# Blind-test Claude without project context
# (follow prompts in zig-knowledge-prompts.md, save responses,
# then compile-test them)
./scripts/zig-knowledge-test.sh probes/
```

If all probes pass and Claude generates correct code without
these docs, the corrections can be retired.

## License

Public domain. Use however you like.
