---
description: >
  Correct Zig 0.15.x patterns for I/O, ArrayList, format strings,
  and build.zig. Use when writing or reviewing any Zig code --
  Claude's training data is outdated for these APIs.
user-invocable: true
---

# Zig 0.15.x Patterns -- Quick Reference

Your Zig training is outdated. This table gives the correct
pattern for each broken one. For full details, code examples,
and error diagnostics, read
`${CLAUDE_PLUGIN_ROOT}/docs/ZIG_BREAKING_CHANGES.md`.

| What Claude Thinks | Reality in 0.15.x | Quick Fix |
|---|---|---|
| `std.io.getStdOut().writer()` | REMOVED (Writergate) | Buffered writer pattern -- see docs |
| `std.io.getStdErr().writer()` | REMOVED (Writergate) | Buffered writer pattern -- see docs |
| `usingnamespace` keyword exists | REMOVED from language | Zero-bit fields + `@fieldParentPtr` |
| `async`/`await` keywords exist | REMOVED from language | Will be library features in future |
| `std.ArrayList(T).init(allocator)` | Managed API removed | `std.ArrayListUnmanaged(T){}`, pass allocator to methods |
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

## Essential Rules

- Always `defer flush() catch {}` on a buffered writer or data
  is lost.
- Use `appendRemaining`, not a `while` loop calling
  `takeDelimiterExclusive` -- that hangs on stdin.
- `std.testing.expectEqual` and friends take expected first,
  actual second.

When you hit a compile error, read
`${CLAUDE_PLUGIN_ROOT}/docs/ZIG_BREAKING_CHANGES.md` for the
matching error message, full code patterns, and migration
strategies.
