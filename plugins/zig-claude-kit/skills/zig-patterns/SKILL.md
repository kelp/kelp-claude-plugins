---
description: >
  Correct Zig 0.15.x patterns for I/O, ArrayList, format strings,
  and build.zig. Use when writing or reviewing any Zig code --
  Claude's training data is outdated for these APIs.
---

# Zig 0.15.x Patterns -- Quick Reference

Your Zig training is outdated. These are the CORRECT patterns.
For full details with error diagnostics, read
`${CLAUDE_PLUGIN_ROOT}/docs/ZIG_BREAKING_CHANGES.md`.

## I/O: Buffered Writers (Writergate)

```zig
// main() setup
var stdout_buffer: [4096]u8 = undefined;
var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
const stdout = &stdout_writer.interface;
defer stdout.flush() catch {};

// stdin reader
var stdin_buffer: [4096]u8 = undefined;
var stdin_reader = std.fs.File.stdin().reader(&stdin_buffer);
const stdin = &stdin_reader.interface;

// File reader
var file_buffer: [4096]u8 = undefined;
var file_reader = file.reader(&file_buffer);
const reader = &file_reader.interface;
```

WRONG: `std.io.getStdOut()`, `std.io.getStdErr()` -- deleted.
ALWAYS `defer flush() catch {}` before buffer goes out of scope.

Use `writerStreaming()` instead of `writer()` when output
must respect O_APPEND (e.g. shell `>>` redirects). The
positional `writer()` uses `pwritev` at offset 0, ignoring
O_APPEND on macOS.

## Reading Input: appendRemaining

```zig
// Read all input at once
var content_list = std.ArrayListUnmanaged(u8){};
defer content_list.deinit(allocator);
reader.appendRemaining(
    allocator, &content_list, .{ .max = 1 << 30 },
) catch |err| {
    return err;
};
const content = content_list.items;
```

WRONG: `while (reader.takeDelimiterExclusive('\n'))` in a loop.
That pattern hangs on stdin in unit tests.

## ArrayList: Allocator on Every Call

```zig
var list = std.ArrayListUnmanaged(u8){};
defer list.deinit(allocator);
try list.append(allocator, value);
try list.appendSlice(allocator, slice);
```

WRONG: `list.append(value)` without allocator.

## Division: Signed Integers

```zig
// WRONG (your training)
const result = a / b;  // runtime signed integers

// RIGHT (Zig 0.15.x)
const result = @divTrunc(a, b);  // or @divFloor, @divExact
const remainder = @rem(a, b);    // or @mod
```

WRONG: `/` and `%` on runtime signed integers -- compile error.

## Format Strings: Explicit Specifiers

```zig
try writer.print("{s}: {d} bytes\n", .{ name, count });
```

WRONG: `"{}"` -- must use `{s}`, `{d}`, `{any}`, etc.
Use `{f}` to call custom format methods.

## Tokenization: Renamed Functions

```zig
// WRONG (your training)
var it = std.mem.tokenize(u8, text, " ");

// RIGHT (Zig 0.15.x)
var it = std.mem.tokenizeAny(u8, text, " ");     // multi-char delimiters
var it = std.mem.tokenizeScalar(u8, text, ' ');   // single char
var it = std.mem.tokenizeSequence(u8, text, "=="); // exact sequence
```

## Process Args: Owned Slice

```zig
// WRONG (your training)
var args = std.process.args();
while (args.next()) |arg| {}

// RIGHT (Zig 0.15.x)
const args = try std.process.argsAlloc(allocator);
defer std.process.argsFree(allocator, args);
for (args[1..]) |arg| {}  // skip program name
```

## For Loops: Explicit Index Range

```zig
// WRONG (your training)
for (items) |item, i| {}

// RIGHT (Zig 0.15.x)
for (items, 0..) |item, i| {}       // explicit index
for (a, b, c) |x, y, z| {}         // multiple arrays
for (names, ages, 0..) |n, a, i| {} // multi-array with index
```

## JSON: Complete Redesign

```zig
// WRONG (your training)
var parser = std.json.Parser.init(allocator, false);
defer parser.deinit();
var tree = try parser.parse(json_text);

// RIGHT (Zig 0.15.x)
const parsed = try std.json.parseFromSlice(T, allocator, text, .{});
defer parsed.deinit();
const value = parsed.value;
```

## Build System: root_module

```zig
const exe = b.addExecutable(.{
    .name = "app",
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    }),
});
```

WRONG: `.root_source_file` at top level of addExecutable.

## Testing: Parameter Order

```zig
// Expected FIRST, actual SECOND
try std.testing.expectEqual(expected, actual);
try std.testing.expectEqualSlices(u8, expected, actual);
try std.testing.expectEqualStrings(expected, actual);
```

## Shell Rules

Run commands exactly as shown. Do NOT append `2>&1`,
`; echo "EXIT: $?"`, or pipe redirections. The Bash tool
captures stdout, stderr, and exit codes automatically.
