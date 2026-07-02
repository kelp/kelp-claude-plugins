---
description: >
  Correct Zig patterns for I/O, ArrayList, format strings,
  build.zig, and (for 0.16) the Io interface, std.fs -> std.Io
  move, and indexOf -> find rename. Use when writing or
  reviewing any Zig code -- Claude's training data is outdated
  for these APIs. Detects whether the project targets 0.15.x
  or 0.16.x and shows the matching reference.
user-invocable: true
---

# Zig Patterns -- Quick Reference

Your Zig training is outdated. The tables below give the
correct pattern for each broken one. The plugin supports both
0.15.x and 0.16.x; detect the version first, then apply the
shared corrections plus the version-specific ones.

## 1. Detect Zig version

Run:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/detect-zig-version.sh
```

It prints `0.15` or `0.16`.

## 2. Shared corrections (both versions)

| What Claude Thinks | Reality | Quick Fix |
|---|---|---|
| `std.io.getStdOut().writer()` | REMOVED (Writergate) | Buffered writer pattern -- see docs |
| `std.io.getStdErr().writer()` | REMOVED (Writergate) | Buffered writer pattern -- see docs |
| `usingnamespace` keyword exists | REMOVED from language | Zero-bit fields + `@fieldParentPtr` |
| `async`/`await` keywords exist | REMOVED from language | Will be library features in future |
| `std.ArrayList(T).init(allocator)` | Managed API removed | Unmanaged list, pass allocator to methods |
| `std.BoundedArray` exists | REMOVED | `ArrayListUnmanaged.initBuffer(&buffer)` |
| `{}` in format strings calls format | Ambiguous -- compile error | Use `{f}` to call format methods |
| Generic writers with `anytype` | Concrete `std.Io.Writer` type | Non-generic with buffer in interface |
| `std.io.BufferedWriter` exists | REMOVED | Writers have built-in buffering |
| Build uses `.root_source_file` | Moved inside `.root_module` | `b.createModule(.{ .root_source_file = ... })` |
| `/` works on runtime signed ints | Must be comptime-known and positive | Use `@divTrunc`, `@divFloor`, or `@divExact` |
| `%` works on runtime signed ints | Must be comptime-known and positive | Use `@rem` or `@mod` |
| `std.mem.tokenize` | Renamed | `tokenizeAny`, `tokenizeScalar`, `tokenizeSequence` |
| `std.process.args()` returns iterator | Now `argsAlloc(allocator)` | Returns owned slice, must free |
| `std.json.Parser` | Complete redesign | `std.json.parseFromSlice(T, allocator, text, .{})` |
| `for (items) \|item, i\|` | Index requires explicit range | `for (items, 0..) \|item, i\|` |
| `std.fifo.LinearFifo` exists | REMOVED | Use `std.Io.Reader`/`Writer` |
| `std.RingBuffer` exists | REMOVED | Use `std.Io.Reader`/`Writer` |
| Arithmetic on `undefined` allowed | Causes illegal behavior | Never operate on undefined values |
| `std.DoublyLinkedList(T)` generic | De-genericified | Intrusive nodes with `@fieldParentPtr` |
| `std.testing.expectEqualSlices` | Parameters swapped | Expected first, actual second |
| `File.writer()` respects O_APPEND | Uses positional writes | Use `writerStreaming()` for append |

Essential rules:

- Always `defer flush() catch {}` on a buffered writer or data
  is lost.
- Use `appendRemaining`, not a `while` loop calling
  `takeDelimiterExclusive` -- that hangs on stdin.
- `std.testing.expectEqual` and friends take expected first,
  actual second.

## 3. 0.16-only corrections (skip for 0.15 projects)

| What Claude Thinks | Reality in 0.16.x | Quick Fix |
|---|---|---|
| `file.close()` takes no args | Every blocking API takes `io: Io` | Thread `io` through the call chain |
| `std.fs.File` / `std.fs.cwd()` | `std.fs.*` moved | `std.Io.File`, `std.Io.Dir.cwd()` |
| `std.mem.indexOf*` | Renamed | `std.mem.find*` (+ new `cut*` family) |
| `std.os.environ` is global | Gone | `pub fn main(init: std.process.Init)`, route `init.environ_map` |
| `std.process.Child.init/spawn` | Redesigned | `std.process.spawn(io, .{...})` |
| `std.Thread.{Mutex,Condition,...}` | Moved | `std.Io.{Mutex,Condition,Event,Group,...}` |
| `@Type(.{ .int = ... })` | Split up | `@Int(...)` and 7 other concrete builtins |
| `std.io.fixedBufferStream` | REMOVED | `std.Io.Writer/.Reader = .fixed(...)` |
| `File.Stat.atime` non-optional | Now optional | `orelse error.FileAccessTimeUnavailable` |

This is the top of the list, not all of it -- the full 0.16
catalog (18 items plus error renames) is in the reference
below.

## 4. When you hit a compile error

Read the authoritative sheet for the detected version:

```
${CLAUDE_PLUGIN_ROOT}/docs/$VERSION/ZIG_BREAKING_CHANGES.md
```

It contains the full quick-reference table, the compile-error
messages that mean your training is wrong, and side-by-side
WRONG / RIGHT code blocks for every pattern. If a pattern
isn't there, fall back to the on-disk Zig reference for the
matching version (e.g. `docs/zig-0.16.0-docs.md` in the
project, when present), or grep `lib/std/` in the installed
Zig.

## Shell Rules

Run commands exactly as shown. Do NOT append `2>&1`,
`; echo "EXIT: $?"`, or pipe redirections. The Bash tool
captures stdout, stderr, and exit codes automatically.
