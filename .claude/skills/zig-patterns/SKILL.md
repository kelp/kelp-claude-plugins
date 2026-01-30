---
description: Zig 0.15.x correct patterns
model-invocation: true
---

# Zig 0.15.x Patterns -- Quick Reference

Your Zig training is outdated. These are the CORRECT patterns.

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

## Format Strings: Explicit Specifiers

```zig
try writer.print("{s}: {d} bytes\n", .{ name, count });
```

WRONG: `"{}"` -- must use `{s}`, `{d}`, `{any}`, etc.
Use `{f}` to call custom format methods.

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
