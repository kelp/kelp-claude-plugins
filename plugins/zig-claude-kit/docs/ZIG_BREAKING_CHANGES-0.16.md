# Zig 0.16 Breaking Changes - Training Override Sheet

This document corrects Claude's outdated training data with current
Zig 0.16 reality. 0.16 (released 2026-04-14) is a Writergate-scale
churn release on top of 0.15.x. The headline is **"I/O as an
Interface"**, and it ripples through `std.fs`, `std.process`,
`std.Thread`, `std.crypto`, `std.time`, and the language itself.

If you learned Zig from 0.13/0.14 (the "managed ArrayList" generation),
or from 0.15 (the "Writergate" generation), **most of what you know
about touching the outside world is now wrong**. I/O, filesystem,
processes, threads, randomness, time, and even `main` itself have new
shapes.

This sheet covers only the patterns models consistently get wrong in
blind testing. For the full landscape, consult the official 0.16
release notes.

## Quick Reference Table

| Old (<=0.15.x)                                  | New (0.16)                                                          |
|------------------------------------------------|---------------------------------------------------------------------|
| `pub fn main() !void`                          | `pub fn main(init: std.process.Init) !void` ("Juicy Main")          |
| `std.io` namespace                             | `std.Io` (capitalized; old name deprecated)                         |
| `std.fs.Dir`                                   | `std.Io.Dir`                                                        |
| `std.fs.File`                                  | `std.Io.File`                                                       |
| `std.fs.cwd()`                                 | `std.Io.Dir.cwd()`                                                  |
| `file.close()`                                 | `file.close(io)`                                                    |
| `file.write(bytes)` / `writeAll`               | `file.writeStreaming(io, ...)` / `writeStreamingAll(io, ...)`       |
| `file.read(buf)`                               | `file.readStreaming(io, ...)`                                       |
| `dir.makeDir(name)`                            | `dir.createDir(io, name)`                                           |
| `dir.makePath(p)`                              | `dir.createDirPath(io, p)`                                          |
| `file.chmod(mode)`                             | `file.setPermissions(io, ...)`                                      |
| `file.getEndPos()` / `setEndPos()`             | `file.length(io)` / `setLength(io, ...)`                            |
| `std.mem.indexOf(u8, haystack, needle)`        | `std.mem.find(u8, haystack, needle)`                                |
| `std.mem.indexOfScalar(u8, s, c)`              | `std.mem.findScalar(u8, s, c)`                                      |
| `std.mem.lastIndexOf(...)`                     | `std.mem.findLast(...)`                                             |
| `std.mem.lastIndexOfScalar(...)`               | `std.mem.findScalarLast(...)` (note: `Last` after `Scalar`)        |
| `std.os.environ`                               | gone -- use `init.environ_map` from `std.process.Init`              |
| `std.process.argsAlloc(allocator)`             | `init.minimal.args.toSlice(allocator)`                              |
| `std.process.getCwd(buf)` / `getCwdAlloc(a)`   | `std.process.currentPath(io, buf)` / `currentPathAlloc(io, a)`      |
| `std.process.Child.init(...).spawn()`          | `std.process.spawn(io, .{ .argv, .stdin, ... })`                    |
| `std.process.execv(arena, argv)`               | `std.process.replace(io, .{ .argv })`                               |
| `std.posix.PROT.READ \| std.posix.PROT.WRITE`  | `.{ .READ = true, .WRITE = true }`                                  |
| `std.posix.mlock(slice)`                       | `std.process.lockMemory(slice, .{})`                                |
| `std.Thread.Mutex` / `Condition` / `Semaphore` | `std.Io.Mutex` / `Io.Condition` / `Io.Semaphore`                    |
| `std.Thread.Pool` + `spawnWg`                  | `std.Io.async` / `std.Io.Group.async` (Pool removed)                |
| `std.crypto.random.bytes(&buf)`                | `io.random(&buf)`                                                   |
| `std.time.Instant` / `Timer` / `timestamp`     | `std.Io.Timestamp` (one type) / `std.Io.Timestamp.now`              |
| `@Type(.{ .int = .{ ... } })`                  | `@Int(.unsigned, 10)` (and 7 sibling builtins)                      |
| `@cImport({ @cInclude(...) })`                 | `b.addTranslateC(...)` in build.zig                                 |
| `error.RenameAcrossMountPoints` / `NotSameFileSystem` | `error.CrossDevice`                                          |
| `error.SharingViolation`                       | `error.FileBusy`                                                    |
| `error.FileTooBig` (readFileAlloc)             | `error.StreamTooLong`                                               |
| Managed `AutoArrayHashMap` etc.                | `std.array_hash_map.Auto` etc. with `.empty`                        |

## Error Messages That Mean Your Training Is Wrong

```
"no member named 'io'" in std namespace
-> std.io renamed to std.Io (capitalized)

"no member named 'File'" / "no member named 'Dir'" in std.fs
-> Moved: std.Io.File / std.Io.Dir

"expected 2 arguments, found 1" on file.close()
-> close() now takes io. Same for write, read, openFile, etc.

"no member named 'makeDir'"
-> Renamed to createDir(io, name)

"no member named 'argsAlloc'" / "argsFree"
-> Use init.minimal.args.toSlice(allocator) instead

"no member named 'environ'" in std.os
-> Use init.environ_map plumbed from main

"no member named 'getCwd'" in std.process
-> Renamed to currentPath / currentPathAlloc (takes io)

"no member named 'indexOf'" / "indexOfScalar" in std.mem
-> Renamed to find / findScalar (and findLast, findScalarLast)

"no member named 'Pool'" in std.Thread
-> Removed; use std.Io.async or std.Io.Group.async

"no member named 'Instant'" / "Timer" in std.time
-> Use std.Io.Timestamp

"no member named 'Type'" / "@Type undefined"
-> Split into @Int, @Tuple, @Struct, @Union, @Enum, @Pointer, @Fn,
   @EnumLiteral. No @Float / @Array / @Optional -- write the literal.

"error: returning address of expired local variable"
-> Trivial &local returns now rejected. Use `return undefined;` if
   you actually want an invalid pointer.

"runtime vector indexing forbidden"
-> Coerce vector to array first

"no field named 'name' on std.process.Init"
-> Did you mean init.minimal? args / environ live there.
```

## The Headline: I/O as an Interface

**The single biggest change in 0.16.** Anything that potentially
**blocks control flow** or **introduces nondeterminism** now takes an
`Io` parameter -- file I/O, networking, timers, random, sleep, sync
primitives, child processes, even fetching the cwd.

### Implementations of `Io`

- `Io.Threaded` -- threaded backend. Default chosen by Juicy Main.
  Feature-complete and well-tested. Use `-fno-single-threaded` for
  task-level concurrency, `-fsingle-threaded` to disable it.
- `Io.Evented` -- experimental userspace stack switching.
- `Io.Uring` -- Linux io_uring (PoC).
- `Io.Kqueue` -- macOS/BSD kqueue (PoC).
- `Io.Dispatch` -- macOS GCD.
- `Io.failing` -- simulates a system supporting no operations.

### "Juicy Main"

The first parameter of `pub fn main` may be one of:

1. **Missing** -- `pub fn main() void` still legal, but blind.
2. **`process.Init.Minimal`** -- only argv and environ in raw form.
3. **`process.Init`** -- full set: `gpa`, `io`, `arena`,
   `environ_map`, `preopens`, plus nested `minimal`.

**Old:**
```zig
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var stdout_buffer: [8192]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writerStreaming(&stdout_buffer);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};

    try stdout.print("Hello\n", .{});
}
```

**New (0.16):**
```zig
const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;
    _ = gpa;

    try std.Io.File.stdout().writeStreamingAll(io, "Hello\n");

    const args = try init.minimal.args.toSlice(init.arena.allocator());
    for (args) |arg| std.log.info("arg: {s}", .{arg});
}
```

`main`'s contract changed; you now receive `gpa`, `io`, an `arena`, an
`environ_map`, and `preopens` for free.

### When You Don't Have an `Io`

```zig
var threaded: std.Io.Threaded = .init_single_threaded;
const io = threaded.io();
```

Treat this like `std.heap.page_allocator` -- a last resort. The
recommended fix is **plumb `Io` through as a parameter**, ideally from
`main`.

### Tests Get a Free `Io`

```zig
test "demo" {
    const io = std.testing.io;
    const file = try std.Io.Dir.cwd().openFile(io, "hello.txt", .{});
    defer file.close(io);
}
```

Like `std.testing.allocator`, there is now `std.testing.io`.

## Stdout / stderr / stdin

The 0.16 lang ref's "Hello World" uses the **unbuffered** path:

```zig
pub fn main(init: std.process.Init) !void {
    try std.Io.File.stdout().writeStreamingAll(init.io, "Hello, World!\n");
}
```

### Buffered Writer Pattern

```zig
pub fn main(init: std.process.Init) !void {
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer =
        std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};

    var stderr_buffer: [4096]u8 = undefined;
    var stderr_writer =
        std.Io.File.stderr().writerStreaming(init.io, &stderr_buffer);
    const stderr = &stderr_writer.interface;
    defer stderr.flush() catch {};

    try stdout.print("hello: {s}\n", .{name});
}
```

Use `writerStreaming` (not `writer`) for stdout/stderr -- the
positional `writer()` ignores O_APPEND and overwrites instead of
appending on macOS.

Reader and writer signatures are **symmetric**:
```zig
pub fn reader(file: File, io: Io, buffer: []u8) Reader
pub fn readerStreaming(file: File, io: Io, buffer: []u8) Reader
pub fn writer(file: File, io: Io, buffer: []u8) Writer
pub fn writerStreaming(file: File, io: Io, buffer: []u8) Writer
```

### Removed I/O Types

- `std.io.GenericReader` / `AnyReader` -- collapsed into `std.Io.Reader`
- `std.Io.GenericWriter` / `AnyWriter` / `null_writer` / `CountingReader`
- `FixedBufferStream` -- replaced by `Reader.fixed` / `Writer.fixed`

**Old:**
```zig
var fbs = std.io.fixedBufferStream(data);
const reader = fbs.reader();
```

**New:**
```zig
var reader: std.Io.Reader = .fixed(data);
var writer: std.Io.Writer = .fixed(buffer);
```

## Filesystem: `std.fs` -> `std.Io`

All `fs` APIs moved to `Io`. Release notes describe this as "a lot of
breaking changes, but unlike Writergate, this changeset does not
require much critical thinking." Typical upgrade:

**Old:**
```zig
file.close();
```

**New:**
```zig
file.close(io);
```

### Namespace Moves

| Old                              | New                              |
|----------------------------------|----------------------------------|
| `std.fs.Dir`                     | `std.Io.Dir`                     |
| `std.fs.File`                    | `std.Io.File`                    |
| `std.fs.cwd`                     | `std.Io.Dir.cwd`                 |
| `std.fs.path`                    | `std.Io.Dir.path` (alias)        |
| `std.fs.max_path_bytes`          | `std.Io.Dir.max_path_bytes`      |
| `std.fs.has_executable_bit`      | `std.Io.File.Permissions.has_executable_bit` |

### Self-Executable Helpers

| Old                            | New                                |
|--------------------------------|------------------------------------|
| `fs.openSelfExe`               | `std.process.openExecutable`       |
| `fs.selfExePath`               | `std.process.executablePath`       |
| `fs.selfExePathAlloc`          | `std.process.executablePathAlloc`  |
| `fs.selfExeDirPath`            | `std.process.executableDirPath`    |
| `fs.Dir.setAsCwd`              | `std.process.setCurrentDir`        |

### Dir Method Renames

| Old                              | New                                  |
|----------------------------------|--------------------------------------|
| `Dir.makeDir`                    | `Dir.createDir`                      |
| `Dir.makePath`                   | `Dir.createDirPath`                  |
| `Dir.makeOpenDir`                | `Dir.createDirPathOpen`              |
| `Dir.atomicSymLink`              | `Dir.symLinkAtomic`                  |
| `Dir.chmod`                      | `Dir.setPermissions`                 |
| `Dir.chown`                      | `Dir.setOwner`                       |
| `Dir.realpath`                   | `Dir.realPathFile`                   |
| `Dir.realpathAlloc`              | `Dir.realPathFileAlloc`              |

`Dir.rename` now requires two `Dir` parameters plus `Io`.

### File Method Renames

| Old                              | New                                  |
|----------------------------------|--------------------------------------|
| `File.Mode`                      | `File.Permissions`                   |
| `File.default_mode`              | `File.Permissions.default_file`      |
| `File.setEndPos` / `getEndPos`   | `File.setLength` / `File.length`     |
| `File.chmod` / `chown`           | `File.setPermissions` / `setOwner`   |
| `File.updateTimes`               | `File.setTimestamps` / `setTimestampsNow` |
| `File.read` / `readv`            | `File.readStreaming`                 |
| `File.pread` / `preadv`          | `File.readPositional`                |
| `File.write` / `writev`          | `File.writeStreaming`                |
| `File.writeAll`                  | `File.writeStreamingAll`             |
| `File.pwrite` / `pwritev`        | `File.writePositional`               |
| `File.pwriteAll`                 | `File.writePositionalAll`            |

### Signature Reshapes -- Not Mechanical

**`readFileAlloc`:**
```zig
// Old
const contents = try std.fs.cwd().readFileAlloc(allocator, name, 1234);

// New
const contents = try std.Io.Dir.cwd().readFileAlloc(
    io, name, allocator, .limited(1234),
);
```

Limit semantics changed: reaching the limit returns the error
(`error.StreamTooLong`, formerly `FileTooBig`).

**`readToEndAlloc`:**
```zig
// Old
const contents = try file.readToEndAlloc(allocator, 1234);

// New
var read_buffer: [4096]u8 = undefined;
var file_reader = file.reader(io, &read_buffer);
const contents = try file_reader.interface.allocRemaining(
    allocator, .limited(1234),
);
```

### Atomic File Rewrite

```zig
var atomic_file = try dest_dir.createFileAtomic(io, dest_path, .{
    .permissions = perms,
    .make_path = true,
    .replace = true,
});
defer atomic_file.deinit(io);

var buffer: [1024]u8 = undefined;
var file_writer = atomic_file.file.writer(io, &buffer);
// ... use file_writer
try file_writer.flush();
try atomic_file.replace(io);
```

Buffer ownership moved from the atomic-file struct to the writer.

## `std.mem.indexOf*` -> `find*`

The rename rule: "find" returns the index of a substring; "pos" is a
starting-index parameter; "last" searches from the end; "scalar" means
the substring is one element.

| Old                          | New                       |
|------------------------------|---------------------------|
| `indexOf`                    | `find`                    |
| `indexOfScalar`              | `findScalar`              |
| `indexOfPos`                 | `findPos`                 |
| `indexOfAny`                 | `findAny`                 |
| `lastIndexOf`                | `findLast`                |
| `lastIndexOfScalar`          | `findScalarLast`          |
| `lastIndexOfAny`             | `findLastAny`             |

**Note:** 0.16 puts the `Last` qualifier *after* `Scalar`, not before
(`findScalarLast`, not `findLastScalar`). There is no `findLastPos`.

### New `cut*` Family

`cut`, `cutPrefix`, `cutSuffix`, `cutScalar`, `cutLast`,
`cutScalarLast`. Split a string at the first (or last) occurrence of a
delimiter, returning the prefix/suffix pair -- the equivalent of Go's
`strings.Cut`.

## Process State (Args & Env) Is No Longer Global

`std.os.environ` was a footgun: declared global but not populatable
without libc, and unsoundly mutable from threads. **As of 0.16,
environment variables are available only through `main`'s parameter.**

### Reading Args

**Old:**
```zig
const args = try std.process.argsAlloc(allocator);
defer std.process.argsFree(allocator, args);
for (args[1..]) |arg| {}
```

**New (Init.Minimal, iterator):**
```zig
pub fn main(init: std.process.Init.Minimal) void {
    var args = init.args.iterate();
    while (args.next()) |arg| {
        std.log.info("arg: {s}", .{arg});
    }
}
```

**New (full Init, slice):**
```zig
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    for (args) |arg| std.log.info("arg: {s}", .{arg});
}
```

### Reading Environment

**Old:**
```zig
const home = std.os.getenv("HOME"); // global
```

**New (full Init):**
```zig
pub fn main(init: std.process.Init) !void {
    for (init.environ_map.keys(), init.environ_map.values()) |k, v| {
        std.log.info("env: {s}={s}", .{ k, v });
    }
}
```

**New (Init.Minimal, lazy):**
```zig
pub fn main(init: std.process.Init.Minimal) !void {
    var arena_allocator: std.heap.ArenaAllocator =
        .init(std.heap.page_allocator);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    const home = init.environ.getPosix("HOME"); // ?[]const u8
    const editor = try init.environ.getAlloc(arena, "EDITOR");
    _ = home; _ = editor;
}
```

Functions that need env vars accept either specific values or a
`*const process.Environ.Map` parameter -- same plumbing as `Allocator`
and `Io`.

## `std.process` / `std.posix` Rewrites

### Current Working Directory Renamed

```zig
// Old
const cwd = try std.process.getCwd(buffer);
const cwd_alloc = try std.process.getCwdAlloc(allocator);

// New
const cwd = try std.process.currentPath(io, buffer);
const cwd_alloc = try std.process.currentPathAlloc(io, allocator);
```

### Spawning a Child Process

```zig
// Old
var child = std.process.Child.init(argv, gpa);
child.stdin_behavior = .Pipe;
child.stdout_behavior = .Pipe;
try child.spawn(io);

// New
var child = try std.process.spawn(io, .{
    .argv = argv,
    .stdin = .pipe,
    .stdout = .pipe,
    .stderr = .pipe,
});
```

`std.process.Child.run` -> `std.process.run(allocator, io, .{...})`.

### Replacing the Current Process Image

```zig
// Old
const err = std.process.execv(arena, argv);

// New
const err = std.process.replace(io, .{ .argv = argv });
```

### Type-Safe POSIX Flags

```zig
// Old
std.posix.PROT.READ | std.posix.PROT.WRITE

// New
.{ .READ = true, .WRITE = true }
```

mlock moved to `process`:

```zig
// Old
try std.posix.mlock();
try std.posix.mlockall(slice, std.posix.MCL_CURRENT);

// New
try std.process.lockMemory(slice, .{});
try std.process.lockMemoryAll(.{ .current = true });
```

### `std.posix` Removals

"Most `std.posix` and `std.os.windows` functions existed at an awkward
**medium-level abstraction** and have thus been removed. If you were
using any functions removed from those namespaces, you must now
choose a direction: **go higher (use `std.Io`) or go lower (use
`std.posix.system` directly)**."

`ucontext_t` and friends are also removed.

## Containers

### Managed Hash Maps Removed

```zig
// Old
var map: std.AutoArrayHashMap(K, V) = .init(allocator);
defer map.deinit();

// New
var map: std.array_hash_map.Auto(K, V) = .empty;
defer map.deinit(allocator);
```

| Old                              | New                          |
|----------------------------------|------------------------------|
| `ArrayHashMap` (managed)         | gone -- use `array_hash_map.Custom` |
| `AutoArrayHashMap` (managed)     | gone -- use `array_hash_map.Auto`   |
| `StringArrayHashMap` (managed)   | gone -- use `array_hash_map.String` |
| `AutoArrayHashMapUnmanaged`      | `array_hash_map.Auto`        |
| `StringArrayHashMapUnmanaged`    | `array_hash_map.String`      |
| `ArrayHashMapUnmanaged`          | `array_hash_map.Custom`      |

Drop the "Managed" variants entirely; the unmanaged variants got the
short names. Pass `allocator` to each method.

### `ArrayList` Uses `.empty`

```zig
var list: std.ArrayList(u8) = .empty;
defer list.deinit(gpa);
try list.append(gpa, 'a');
```

The "managed" form is gone -- only `unmanaged`-style remains, and it
took over the short name.

### Other Container Changes

- `SegmentedList` -- removed, no replacement.
- `PriorityQueue` / `PriorityDequeue` -- lose allocator field, use
  `.empty`. Methods renamed: `add` -> `push`, `remove*` -> `pop*`.
- BitSet / EnumSet -- `initEmpty` / `initFull` replaced by `.empty` /
  `.full` decl literals.

## Sync Primitives: `Thread.*` -> `Io.*`

Sync APIs moved to `std.Io` so synchronized code integrates with the
chosen I/O backend (a contended mutex blocks the thread under
`Io.Threaded`, switches stacks under `Io.Evented`).

| Old                       | New                |
|---------------------------|--------------------|
| `std.Thread.ResetEvent`   | `std.Io.Event`     |
| `std.Thread.WaitGroup`    | `std.Io.Group`     |
| `std.Thread.Futex`        | `std.Io.Futex`     |
| `std.Thread.Mutex`        | `std.Io.Mutex`     |
| `std.Thread.Condition`    | `std.Io.Condition` |
| `std.Thread.Semaphore`    | `std.Io.Semaphore` |
| `std.Thread.RwLock`       | `std.Io.RwLock`    |
| `std.once`                | removed            |
| `std.Thread.Mutex.Recursive` | removed         |

### `std.Thread.Pool` Removed

```zig
// Old
fn doAllTheWork(pool: *std.Thread.Pool) void {
    var wg: std.Thread.WaitGroup = .{};
    pool.spawnWg(wg, doSomeWork, .{ pool, &wg, item });
    wg.wait();
}

// New
fn doAllTheWork(io: std.Io) !void {
    var g: std.Io.Group = .init;
    errdefer g.cancel(io);
    g.async(io, doSomeWork, .{ io, &g, item });
    try g.await(io);
}
```

Lock-free atomics do **not** require `Io` integration.

## Allocators

### `ArenaAllocator` Is Lock-Free Thread-Safe

No API change. Drop any `ThreadSafeAllocator` wrapping you had. Roughly
matches single-threaded performance up to ~7 concurrent threads.

### `heap.ThreadSafeAllocator` Removed

The release notes call it "an anti-pattern". Make the underlying
allocator lock-free instead.

### `DebugAllocator` Renamed

`GeneralPurposeAllocator` -> `DebugAllocator`. For release builds,
prefer `std.heap.smp_allocator` if you don't have a clear arena
lifetime.

## Random / Time / Format

### Entropy

```zig
// Old
std.crypto.random.bytes(&buf);
posix.getrandom(&buf);

// New
io.random(&buf);
io.randomSecure(&buf); // bypasses any in-process RNG state
```

### Time

| Old                       | New                                |
|---------------------------|------------------------------------|
| `std.time.Instant`        | `std.Io.Timestamp`                 |
| `std.time.Timer`          | `std.Io.Timestamp`                 |
| `std.time.timestamp()`    | `std.Io.Timestamp.now`             |

### Format

| Old                       | New                                |
|---------------------------|------------------------------------|
| `std.fmt.Formatter`       | `std.fmt.Alt`                      |
| `std.fmt.format`          | `std.Io.Writer.print`              |
| `std.fmt.FormatOptions`   | `std.fmt.Options`                  |
| `std.fmt.bufPrintZ`       | `std.fmt.bufPrintSentinel`         |

The custom `format` method signature
(`pub fn format(self: T, writer: *std.Io.Writer) !void`) is unchanged
from 0.15.

## Error Renames

| Old                                  | New                              |
|--------------------------------------|----------------------------------|
| `error.RenameAcrossMountPoints`      | `error.CrossDevice`              |
| `error.NotSameFileSystem`            | `error.CrossDevice`              |
| `error.SharingViolation`             | `error.FileBusy`                 |
| `error.EnvironmentVariableNotFound`  | `error.EnvironmentVariableMissing` |
| `error.FileTooBig` (`readFileAlloc`) | `error.StreamTooLong`            |
| `Dir.rename` non-empty dest          | `error.DirNotEmpty` (was `PathAlreadyExists`) |

## Language-Level Changes

### `@Type` Split Into Eight Builtins

`@Type` is gone. Replacements:

```zig
@EnumLiteral() type
@Int(comptime signedness: std.builtin.Signedness, comptime bits: u16) type
@Tuple(comptime field_types: []const type) type
@Pointer(size, attrs, Element, sentinel) type
@Fn(param_types, param_attrs, ReturnType, attrs) type
@Struct(layout, BackingInt, field_names, field_types, field_attrs) type
@Union(layout, ArgType, field_names, field_types, field_attrs) type
@Enum(TagInt, mode, field_names, field_values) type
```

```zig
// Old
@Type(.{ .int = .{ .signedness = .unsigned, .bits = 10 } })
// New
@Int(.unsigned, 10)

// Old
@Type(.enum_literal)
// New
@EnumLiteral()
```

There is **no** `@Float`, `@Array`, `@Opaque`, `@Optional`, or
`@ErrorUnion` -- write the literal type (`f32`, `[N]T`, `opaque {}`,
`?T`, `E!T`). No `@ErrorSet` either; declare with `error{ ... }`.

### `@cImport` Deprecated

`@cImport` still exists but is deprecated. Use `b.addTranslateC(...)`
in `build.zig`:

```zig
// build.zig
const translate_c = b.addTranslateC(.{
    .root_source_file = b.path("src/c.h"),
    .target = target,
    .optimize = optimize,
});
translate_c.linkSystemLibrary("glfw", .{});

const exe = b.addExecutable(.{
    .name = "app",
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .imports = &.{ .{
            .name = "c",
            .module = translate_c.createModule(),
        } },
    }),
});
```

Then `const c = @import("c");` in source.

### Runtime Vector Indexing Forbidden

```zig
// New: coerce to array first
const vt = @typeInfo(@TypeOf(vec)).vector;
const arr: [vt.len]vt.child = vec;
for (&arr) |elem| { _ = elem; }
```

### Trivial Local-Address Returns Forbidden

```zig
fn foo() *i32 {
    var x: i32 = 1234;
    return &x; // error: returning address of expired local
}
```

Spell it as `return undefined;` if you genuinely want an invalid
pointer.

### Small Int -> Float Auto-Coercion

`u24` -> `f32` coerces implicitly (precision bits fit). `u25` still
requires `@floatFromInt`.

### `@floor`/`@ceil`/`@round`/`@trunc` Convert to Integers

```zig
fn round_to_int(value: f32) u8 {
    return @round(value); // returns u8 directly
}
```

`@intFromFloat` is now redundant with `@trunc` and is deprecated.

## Build System

### `build.zig.zon` Required Fields

`zig build` **fails** when:
- A dependency has no `fingerprint` field, or
- A dependency's `name` is a string rather than an enum literal.

Legacy hash format support is removed.

### Local Forks

```sh
zig build --fork=/path/to/local/checkout
```

The fork path must contain a `build.zig.zon` with matching `name` and
`fingerprint`.

### Packages in `zig-pkg/`

Dependencies land in `zig-pkg/` next to `build.zig` (was
`$GLOBAL_ZIG_CACHE/p/$HASH`). Don't commit `zig-pkg/`.

### New Flags

- `--test-timeout 500ms` -- per-`test`-block timeout (real time).
- `--error-style verbose|minimal|verbose_clear|minimal_clear` --
  replaces removed `--prominent-compile-errors`.
- `--multiline-errors indent|newline|none`.

## Carry-Over from 0.15.x

These breaking changes from 0.15 are **still in effect** in 0.16 --
your training is wrong about them too.

### Removed Language Features (from 0.15)

- `usingnamespace` -- replaced by zero-bit fields + `@fieldParentPtr`
- `async` / `await` keywords -- now library features (`std.Io.async`)
- `@frameSize` builtin

### Format Method Signature (from 0.15)

```zig
// WRONG (your training)
pub fn format(self: T, comptime fmt: []const u8,
    options: std.fmt.FormatOptions, writer: anytype) !void { ... }

// RIGHT (0.15 and 0.16)
pub fn format(self: T, writer: *std.Io.Writer)
    std.Io.Writer.Error!void {
    try writer.print("{d}", .{self.x});
}
```

Use `{f}` in format strings to call format methods, not `{}`.

### ArrayList Allocator-Per-Method (from 0.15)

```zig
var list: std.ArrayList(u8) = .empty;
defer list.deinit(allocator);
try list.append(allocator, 'a');
```

### Division on Signed Integers (from 0.15)

```zig
// RIGHT
const q = @divTrunc(a, b);
const r = @rem(a, b);
```

`/` and `%` on runtime signed integers are still compile errors.

### Tokenize Renames (from 0.15)

```zig
std.mem.tokenizeAny(u8, text, " \t");
std.mem.tokenizeScalar(u8, text, ' ');
std.mem.tokenizeSequence(u8, text, "==");
```

### For-Loop Explicit Index (from 0.15)

```zig
for (items, 0..) |item, i| {}
```

### `BoundedArray` Replacement (from 0.15)

```zig
var buffer: [64]u8 = undefined;
var stack = std.ArrayListUnmanaged(u8).initBuffer(&buffer);
```

### JSON Redesign (from 0.15)

```zig
const parsed = try std.json.parseFromSlice(T, allocator, text, .{});
defer parsed.deinit();
```

### Testing Parameter Order (from 0.15)

```zig
try std.testing.expectEqual(expected, actual);
```

## When You're Stuck

1. Grep this file for the symbol or error message
2. Check the 0.16 release notes
3. Check the 0.16 lang ref
4. As a last resort, read `lib/std/Io/...` source in your installed
   Zig -- the lang ref is incomplete, the source is not

The language changed fundamentally. Your instincts are wrong. Always
verify.
