# zig-claude-kit

Corrective context files that fix Claude's outdated Zig training
for 0.15.x projects.

## Problem

Claude consistently generates broken Zig code for 6 specific
patterns. Blind testing against Opus 4.6, Sonnet 4.6 (and
earlier 4.5 models) confirmed these are baked into training
data and persist across fresh conversations with no project
context.

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

Use `just` to run the test suite:

```bash
just              # list all recipes

# Automated: blind-test models via the Claude API
just eval                             # sonnet + opus 4.6
just eval-model claude-haiku-4-5      # test a specific model

# Re-compile existing probes (no API calls)
just compile-test claude-sonnet-4-6

# Validate breaking change claims against current Zig
just audit

# Clean up generated files
just clean
```

Requires `ANTHROPIC_API_KEY` in your environment and `uv`
for the Python eval script.

You can also run the scripts directly:

```bash
# Automated blind test via API
uv run scripts/zig-knowledge-eval.py
uv run scripts/zig-knowledge-eval.py --models claude-sonnet-4-6

# Compiler probes against current Zig version
./scripts/zig-knowledge-audit.sh

# Compile-test previously saved responses
./scripts/zig-knowledge-test.sh probes/claude-sonnet-4-6/
```

If all probes pass and Claude generates correct code without
these docs, the corrections can be retired.

## Latest Results (2026-02-27)

Tested against Zig 0.15.2 with no project context.

| Probe | Sonnet 4.6 | Opus 4.6 |
|-------|------------|----------|
| 01 stdout (Writergate) | FAIL | FAIL |
| 02 stderr (Writergate) | FAIL | FAIL* |
| 03 ArrayList | FAIL | FAIL |
| 04 BoundedArray | FAIL | FAIL |
| 05 tokenize | pass | FAIL |
| 06 testing | pass | pass |
| 07 process args (Writergate) | FAIL | FAIL |
| 08 JSON | pass | FAIL |
| 09 format method | FAIL | FAIL |
| 10 mixin (usingnamespace) | FAIL | FAIL |
| 11 division | pass | pass |
| 12 for loop with index | pass | pass |
| 13 build.zig | FAIL* | FAIL* |
| 14 async/await | FAIL | FAIL |

\* Compiled only due to Zig's lazy analysis (unreferenced
function bodies are not analyzed). Manual inspection confirmed
the code uses the wrong pattern.

All 6 documented blind spots remain in both 4.6 models.

## License

Public domain. Use however you like.
