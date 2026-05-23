# zig-claude-kit

Claude generates broken Zig code. This plugin fixes it by
injecting correct patterns into your project's CLAUDE.md.
Supports both **Zig 0.15.x** and **Zig 0.16** -- detected
automatically from `build.zig.zon`.

## The Problem

Claude's Zig training predates 0.15.x and is doubly outdated
for 0.16 (the I/O-as-Interface release, 2026-04-14). Fourteen
test probes cover the patterns models consistently get wrong
in blind testing.

## What It Corrects

**Carried over from 0.15 (still wrong in 0.16):**

1. `usingnamespace` -- removed from the language
2. `async` / `await` keywords -- removed from the language
3. `std.BoundedArray` -- removed; use
   `ArrayListUnmanaged.initBuffer`
4. `std.ArrayList(T).init(allocator)` -- managed API removed
5. `/` on runtime signed integers -- requires `@divTrunc`
6. `std.mem.tokenize` -- renamed to `tokenizeAny` /
   `tokenizeScalar` / `tokenizeSequence`
7. `std.json.Parser` -- redesigned to
   `std.json.parseFromSlice`
8. `for (items) |item, i|` -- requires explicit
   `for (items, 0..)`
9. Format method signature: `pub fn format(self, writer)`
10. `build.zig` uses `.root_module = b.createModule(...)`

**New in 0.16:**

11. `std.io` -> `std.Io` (and `std.fs.File` -> `std.Io.File`,
    `std.fs.Dir` -> `std.Io.Dir`, `std.fs.cwd()` ->
    `std.Io.Dir.cwd()`)
12. "Juicy Main": `pub fn main(init: std.process.Init) !void`
    brings `gpa`, `io`, `arena`, `environ_map`, `preopens`
13. Every blocking call takes `io` -- `file.close(io)`,
    `file.writeStreaming(io, ...)`, `dir.createDir(io, name)`
14. `std.mem.indexOf*` renamed to `find*` (note
    `findScalarLast`, with `Last` after `Scalar`)
15. `std.os.environ` gone -- use `init.environ_map`
16. `std.process.argsAlloc` / `argsFree` gone -- use
    `init.minimal.args.toSlice(allocator)`
17. `std.process.getCwd` -> `currentPath(io, buf)`
18. `std.process.Child.init(...).spawn()` -> spawn(io, {...})`
19. `std.Thread.Mutex` / `Condition` / `WaitGroup` /
    `Pool` -- moved to `std.Io.*` (Pool replaced by
    `std.Io.async` / `Group.async`)
20. `std.crypto.random.bytes` -> `io.random(&buf)`
21. `std.time.Instant` / `Timer` / `timestamp` -> single
    `std.Io.Timestamp`
22. `@Type` -> 8 builtins (`@Int`, `@Tuple`, `@Struct`, etc.)
23. Managed hash maps gone -- `array_hash_map.Auto` / `String`
    / `Custom` with `.empty`
24. Error renames: `RenameAcrossMountPoints` /
    `NotSameFileSystem` -> `CrossDevice`, `SharingViolation`
    -> `FileBusy`, `FileTooBig` -> `StreamTooLong`

## Install

```bash
/plugin marketplace add kelp/kelp-claude-plugins
/plugin install zig-claude-kit@kelp-claude-plugins
```

## Use

Open a Zig project. The plugin detects Zig source files,
reads `build.zig.zon`'s `minimum_zig_version` (or falls back
to `zig version` or the default 0.16), and prompts you to
run `/zig-init`. That command appends the matching
corrections to your CLAUDE.md. Every agent reads them as
project context.

**Commands:**
- `/zig-init` -- inject version-matched corrections into
  CLAUDE.md
- `/zig-patterns` -- quick reference for both 0.15 and 0.16
- `/zig-check` -- audit source files for outdated APIs (uses
  the detected version's ruleset)

If detection picks the wrong version (e.g. you haven't bumped
`build.zig.zon` yet), set `minimum_zig_version` to match and
re-run `/zig-init`.

## Verify

Run the blind-test suite to confirm corrections remain
necessary against the current Zig:

```bash
make audit                # auto-detects from `zig version`
make audit-0.15           # validate 0.15.x claims
make audit-0.16           # validate 0.16 claims

make eval TARGET=0.16     # blind-test default models
make eval-model MODEL=claude-haiku-4-5 TARGET=0.16
make compile-test MODEL=claude-sonnet-4-6 TARGET=0.16
```

**Prerequisites:** `ANTHROPIC_API_KEY` and `uv` for eval;
`zig` on `PATH` for audit and compile-test.

When all probes pass without corrections, retire this
plugin.

## Reference

- [Breaking Changes -- 0.15.x](docs/ZIG_BREAKING_CHANGES-0.15.md)
- [Breaking Changes -- 0.16](docs/ZIG_BREAKING_CHANGES-0.16.md)
- [CLAUDE.md Fragment -- 0.15.x](docs/claude-md-fragment-0.15.md)
- [CLAUDE.md Fragment -- 0.16](docs/claude-md-fragment-0.16.md)

## License

Public domain.
