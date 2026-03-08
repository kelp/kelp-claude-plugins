# zig-claude-kit

Claude generates broken Zig 0.15.x code. This plugin
fixes it by injecting correct patterns into your
project's CLAUDE.md.

## The Problem

Claude's Zig training predates 0.15.x. Fourteen test
probes cover twelve broken patterns that produce code
which fails to compile. Testing against Opus 4.6 and
Sonnet 4.6 without project context confirmed all twelve
persist across fresh conversations.

## What It Corrects

1. **Writergate** -- `getStdOut()`/`getStdErr()` removed;
   buffered writer pattern required
2. **build.zig** -- `.root_source_file` moved inside
   `.root_module = b.createModule(...)`
3. **Format specifiers** -- generic `{}` removed; use
   `{s}`, `{d}`, `{any}`, or `{f}` for format methods
4. **usingnamespace** -- removed from language
5. **BoundedArray** -- removed; use
   `ArrayListUnmanaged.initBuffer`
6. **ArrayList.init()** -- managed API removed; use
   `ArrayListUnmanaged{}` with allocator per call
7. **Signed division** -- `/` on runtime signed integers
   requires `@divTrunc`
8. **tokenize** -- renamed to `tokenizeAny`,
   `tokenizeScalar`, `tokenizeSequence`
9. **process.args()** -- now `argsAlloc(allocator)`;
   returns owned slice
10. **For-loop index** -- requires explicit range:
    `for (items, 0..) |item, i|`
11. **async/await** -- removed from the language
12. **JSON Parser** -- redesigned to
    `std.json.parseFromSlice`

## Install

```bash
/plugin marketplace add kelp/kelp-claude-plugins
/plugin install zig-claude-kit@kelp-claude-plugins
```

## Use

Open a Zig project. The plugin detects Zig source files
and prompts you to run `/zig-init`. That command appends
corrections to your CLAUDE.md. Every agent reads them
as project context.

**Commands:**
- `/zig-init` -- inject corrections into CLAUDE.md
- `/zig-patterns` -- quick reference with code examples
- `/zig-check` -- audit source files for outdated APIs

## Verify

Run the blind-test suite to confirm corrections remain
necessary:

```bash
make eval                              # test all models
make eval-model MODEL=claude-haiku-4-5 # test one model
make audit                             # probe current Zig
make compile-test MODEL=claude-sonnet-4-6
```

**Prerequisites:** `ANTHROPIC_API_KEY` and `uv`.

## Latest Results (2026-02-27)

Tested against Zig 0.15.2, no project context.

| Probe | Sonnet 4.6 | Opus 4.6 |
|-------|------------|----------|
| 01 stdout (Writergate) | FAIL | FAIL |
| 02 stderr (Writergate) | FAIL | FAIL* |
| 03 ArrayList | FAIL | FAIL |
| 04 BoundedArray | FAIL | FAIL |
| 05 tokenize | pass | FAIL |
| 06 testing | pass | pass |
| 07 process args | FAIL | FAIL |
| 08 JSON | pass | FAIL |
| 09 format method | FAIL | FAIL |
| 10 mixin (usingnamespace) | FAIL | FAIL |
| 11 division | pass | pass |
| 12 for loop with index | pass | pass |
| 13 build.zig | FAIL* | FAIL* |
| 14 async/await | FAIL | FAIL |

\* Compiled only due to lazy analysis. Manual inspection
confirmed wrong patterns.

When all probes pass without corrections, retire this
plugin.

## Reference

- [Breaking Changes](docs/ZIG_BREAKING_CHANGES.md) --
  full reference with error diagnostics
- [CLAUDE.md Fragment](docs/claude-md-fragment.md) --
  corrections appended by `/zig-init`

## License

Public domain.
