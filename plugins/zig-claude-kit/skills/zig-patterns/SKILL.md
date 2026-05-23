---
description: >
  Correct Zig patterns for I/O, ArrayList, format strings, and
  build.zig. Auto-detects whether the project targets 0.15.x or
  0.16. Use when writing or reviewing any Zig code -- Claude's
  training data is outdated for these APIs.
---

# Zig Patterns -- Quick Reference

Your Zig training is outdated. Before writing patterns, run
`${CLAUDE_PLUGIN_ROOT}/scripts/detect-zig-version.sh` to learn
whether the current project targets **Zig 0.15.x** or **Zig
0.16**. The two versions have different "right answers" for
I/O, args, environment, and filesystem code.

For full details with error diagnostics, read the
version-specific reference:

- 0.15.x: `${CLAUDE_PLUGIN_ROOT}/docs/ZIG_BREAKING_CHANGES-0.15.md`
- 0.16:   `${CLAUDE_PLUGIN_ROOT}/docs/ZIG_BREAKING_CHANGES-0.16.md`

When the user invokes this skill, identify which version the
project targets and show the matching patterns below. If
unsure, default to 0.16 (the current release as of 2026-04-14).

---

## Zig 0.16 Patterns

### "Juicy Main"

```zig
const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;
    const arena = init.arena.allocator();
    _ = gpa; _ = arena;

    try std.Io.File.stdout().writeStreamingAll(io, "Hello!\n");
}
```

`std.process.Init` bundles `gpa`, `io`, `arena`, `environ_map`,
`preopens`, plus `init.minimal.{args,environ}`.

### Buffered stdout/stderr (0.16)

```zig
pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer =
        std.Io.File.stdout().writerStreaming(io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};

    try stdout.print("Hello, {s}\n", .{name});
}
```

`std.io.getStdOut()` and `std.fs.File.stdout()` are both wrong
in 0.16. Use `std.Io.File.stdout()` and pass `io` to
`writerStreaming`. Use `writerStreaming` (not `writer`) so
shell `>>` redirects work on macOS.

### Args and environment (no longer global)

```zig
// Slice via Juicy Main
const args = try init.minimal.args.toSlice(init.arena.allocator());
for (args) |arg| std.log.info("{s}", .{arg});

// Iterator via Init.Minimal
var it = init.minimal.args.iterate();
while (it.next()) |arg| {}

// Env via Juicy Main
const home = init.environ_map.get("HOME");
```

`std.os.environ`, `std.process.argsAlloc`, and
`std.process.argsFree` are gone.

### Filesystem (moved to std.Io)

```zig
const dir = std.Io.Dir.cwd();
const file = try dir.openFile(io, "x.txt", .{});
defer file.close(io);

try dir.createDir(io, "newdir");
try dir.createDirPath(io, "deep/nested/path");
```

`std.fs.File` -> `std.Io.File`, `std.fs.Dir` -> `std.Io.Dir`,
every blocking method takes `io`.

### `std.mem.indexOf*` renamed to `find*`

```zig
const i = std.mem.find(u8, haystack, needle);
const j = std.mem.findScalar(u8, s, ' ');
const k = std.mem.findLast(u8, haystack, needle);
const l = std.mem.findScalarLast(u8, s, '/');  // Last after Scalar
```

### Process / spawning

```zig
const child = try std.process.spawn(io, .{
    .argv = argv,
    .stdin = .pipe,
    .stdout = .pipe,
    .stderr = .pipe,
});

const cwd = try std.process.currentPathAlloc(io, allocator);
defer allocator.free(cwd);
```

### Sync primitives (moved to Io)

```zig
var mutex: std.Io.Mutex = .{};
var cond: std.Io.Condition = .{};
var group: std.Io.Group = .init;
errdefer group.cancel(io);
group.async(io, task, .{io});
try group.await(io);
```

`std.Thread.Pool` is gone. Lock-free atomics still work without
`Io`.

### Tests get a free `Io`

```zig
test "io test" {
    const io = std.testing.io;
    const file = try std.Io.Dir.cwd().openFile(io, "x", .{});
    defer file.close(io);
}
```

### Hash maps

```zig
var map: std.array_hash_map.Auto(K, V) = .empty;
defer map.deinit(gpa);
try map.put(gpa, k, v);
```

### `ArrayList` (carried from 0.15)

```zig
var list: std.ArrayList(u8) = .empty;
defer list.deinit(gpa);
try list.append(gpa, 'a');
```

### Builtins replacing `@Type`

```zig
const T = @Int(.unsigned, 10);
const Pair = @Tuple(&.{ u32, [2]f64 });
const tag = @EnumLiteral();
```

No `@Float`, `@Array`, `@Optional`, `@ErrorUnion` -- write the
literal type.

---

## Zig 0.15.x Patterns

### I/O: Buffered Writers (Writergate, 0.15 edition)

```zig
var stdout_buffer: [4096]u8 = undefined;
var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
const stdout = &stdout_writer.interface;
defer stdout.flush() catch {};

var stdin_buffer: [4096]u8 = undefined;
var stdin_reader = std.fs.File.stdin().reader(&stdin_buffer);
const stdin = &stdin_reader.interface;
```

WRONG: `std.io.getStdOut()`, `std.io.getStdErr()` -- deleted.
ALWAYS `defer flush() catch {}` before buffer goes out of scope.

Use `writerStreaming()` instead of `writer()` when output must
respect O_APPEND (e.g. shell `>>` redirects).

### Reading Input: appendRemaining

```zig
var content_list = std.ArrayListUnmanaged(u8){};
defer content_list.deinit(allocator);
reader.appendRemaining(
    allocator, &content_list, .{ .max = 1 << 30 },
) catch |err| return err;
const content = content_list.items;
```

WRONG: `while (reader.takeDelimiterExclusive('\n'))` in a loop.

### ArrayList: Allocator on Every Call

```zig
var list = std.ArrayListUnmanaged(u8){};
defer list.deinit(allocator);
try list.append(allocator, value);
```

### Process Args: Owned Slice

```zig
const args = try std.process.argsAlloc(allocator);
defer std.process.argsFree(allocator, args);
for (args[1..]) |arg| {}
```

### Build System: root_module

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

---

## Shared Across Both Versions

These corrections apply to both 0.15.x and 0.16.

### Division: Signed Integers

```zig
const result = @divTrunc(a, b);  // or @divFloor, @divExact
const remainder = @rem(a, b);    // or @mod
```

WRONG: `/` and `%` on runtime signed integers -- compile error.

### Format Strings: Explicit Specifiers

```zig
try writer.print("{s}: {d} bytes\n", .{ name, count });
```

WRONG: `"{}"` -- must use `{s}`, `{d}`, `{any}`, etc.
Use `{f}` to call custom format methods.

### Tokenization: Renamed Functions

```zig
var it = std.mem.tokenizeAny(u8, text, " ");      // multi-char
var it = std.mem.tokenizeScalar(u8, text, ' ');   // single
var it = std.mem.tokenizeSequence(u8, text, "=="); // exact
```

### For Loops: Explicit Index Range

```zig
for (items, 0..) |item, i| {}
for (a, b, c) |x, y, z| {}
for (names, ages, 0..) |n, a, i| {}
```

### JSON: parseFromSlice

```zig
const parsed = try std.json.parseFromSlice(T, allocator, text, .{});
defer parsed.deinit();
const value = parsed.value;
```

### Testing: Parameter Order

```zig
// Expected FIRST, actual SECOND
try std.testing.expectEqual(expected, actual);
try std.testing.expectEqualSlices(u8, expected, actual);
try std.testing.expectEqualStrings(expected, actual);
```

### Removed Language Features

- `usingnamespace` -- gone. Use zero-bit fields with
  `@fieldParentPtr`.
- `async` / `await` keywords -- gone. In 0.16 use `std.Io.async`.
- `std.BoundedArray` -- gone. Use
  `ArrayListUnmanaged.initBuffer`.

### Format Method Signature

```zig
pub fn format(self: T, writer: *std.Io.Writer)
    std.Io.Writer.Error!void {
    try writer.print("{d}", .{self.x});
}
```

Use `{f}` in format strings to call format methods, not `{}`.

## Shell Rules

Run commands exactly as shown. Do NOT append `2>&1`,
`; echo "EXIT: $?"`, or pipe redirections. The Bash tool
captures stdout, stderr, and exit codes automatically.
