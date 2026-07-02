# Zig 0.16.x Breaking Changes - Training Override Sheet

This document corrects Claude's outdated training data with
current Zig 0.16.x reality. It covers only the patterns that
models consistently get wrong in blind testing.

0.16 is a Writergate-scale churn release. The headline is
"I/O as an Interface", and it ripples through `std.fs`,
`std.process`, `std.Thread`, `std.crypto`, `std.time`, and the
language itself. Every change in the 0.15 sheet still applies
unless explicitly overridden below.

## Quick Reference Table

| What Claude Thinks | Reality in 0.16.x | Quick Fix |
|---|---|---|
| `pub fn main() !void` is the only shape | Three legal shapes now ("Juicy Main") | Take `init: std.process.Init` |
| `std.io.getStdOut().writer()` | REMOVED | `std.Io.File.stdout().writeStreamingAll(io, "...")` |
| `std.fs.File.stdout()` | Moved namespace | `std.Io.File.stdout()` |
| `std.fs.Dir` / `std.fs.File` | Moved | `std.Io.Dir` / `std.Io.File` |
| `std.fs.cwd()` | Moved | `std.Io.Dir.cwd()` |
| `file.close()` / `file.read(buf)` | Need `io` | `file.close(io)` / `file.readStreaming(io, ...)` |
| `dir.makeDir(name)` / `makePath(p)` | Renamed | `dir.createDir(io, name)` / `createDirPath(io, p)` |
| `std.io` namespace | Capitalized | `std.Io` |
| `std.mem.indexOf*` | Renamed | `std.mem.find*` (full family) |
| `std.os.environ` | REMOVED (was global) | `init.environ_map` from `std.process.Init` |
| `std.process.argsAlloc(allocator)` | Phased out | `init.minimal.args.toSlice(arena)` |
| `std.process.getCwd(buf)` | Renamed | `std.process.currentPath(io, buf)` |
| `std.process.Child.init(...).spawn()` | Reshaped | `std.process.spawn(io, .{ .argv, ... })` |
| `std.process.execv(arena, argv)` | Renamed | `std.process.replace(io, .{ .argv })` |
| `std.Thread.Mutex/Condition/...` | Moved | `std.Io.Mutex/Condition/...` |
| `std.Thread.Pool` + `spawnWg` | REMOVED | `std.Io.Group` + `g.async(io, ...)` |
| `std.heap.ThreadSafeAllocator` | REMOVED | `ArenaAllocator` is lock-free thread-safe now |
| `std.crypto.random.bytes(&buf)` | Moved | `io.random(&buf)` |
| `std.time.Instant` / `Timer` / `timestamp()` | One type | `std.Io.Timestamp` / `std.Io.Timestamp.now` |
| `std.fmt.Formatter` | Renamed | `std.fmt.Alt` |
| `std.fmt.format` | Moved | `std.Io.Writer.print` |
| `std.fmt.bufPrintZ` | Renamed | `std.fmt.bufPrintSentinel` |
| `std.AutoArrayHashMap(K,V)` (managed) | REMOVED | `std.array_hash_map.Auto(K,V)` (was Unmanaged) |
| `std.SegmentedList` | REMOVED | No replacement; use `ArrayListUnmanaged` |
| `PriorityQueue.init(allocator, ctx)` | `.empty` literal | `.empty` then pass allocator to methods |
| `pq.add(x)` / `pq.remove()` | Renamed | `pq.push(allocator, x)` / `pq.pop()` |
| `@Type(.{ .int = .{...} })` | Split into 8 builtins | `@Int(.unsigned, 10)` |
| `@cImport({ ... })` | Deprecated | `b.addTranslateC(...)` in build.zig |
| `vector[i]` with runtime `i` | Forbidden | Coerce to array first |
| `return &local_var;` (trivial) | Compile error | Spell `return undefined;` if intentional |
| `std.io.fixedBufferStream(data)` | REMOVED | `var r: std.Io.Reader = .fixed(data);` |
| `GenericReader`/`AnyReader`/`AnyWriter` | REMOVED | Concrete `std.Io.Reader` / `std.Io.Writer` |
| `error.RenameAcrossMountPoints` | Renamed | `error.CrossDevice` |
| `error.SharingViolation` | Renamed | `error.FileBusy` |
| `error.EnvironmentVariableNotFound` | Renamed | `error.EnvironmentVariableMissing` |
| `error.FileTooBig` (`readFileAlloc`) | Renamed | `error.StreamTooLong` |
| `File.Stat.atime` is non-null | Optional | `stat.atime orelse return error...` |
| `File.Mode` / `File.PermissionsUnix` | Unified | `File.Permissions` |
| `std.builtin.subsystem` | REMOVED | `std.zig.Subsystem` |
| `--prominent-compile-errors` | REMOVED | `--error-style {verbose,minimal,...}` |
| `Build.makeTempPath` / `RemoveDir` step | REMOVED | `b.addTempFiles` / `b.tmpPath()` |

The 0.15 patterns still in play (Writergate basics for
non-stdout writers, ArrayList unmanaged, `usingnamespace`
gone, `async`/`await` gone, signed division builtins, `{f}`
format specifier, build system `.root_module`, BoundedArray
removal, JSON parser shape, `for (items, 0..)` index syntax)
are unchanged in 0.16. See the 0.15.x sheet for those.

## Error Messages That Mean Your Training Is Wrong

```
"expected type 'std.process.Init', found 'void'"
-> main now takes a process.Init parameter (Juicy Main)

"no member named 'getStdOut'"
"no member named 'getStdErr'"
-> Writergate plus namespace move - std.Io.File.stdout()

"root struct of file 'fs' has no member named 'cwd'"
-> std.fs.cwd() moved to std.Io.Dir.cwd()

"no member named 'Dir' in struct 'fs'"
"no member named 'File' in struct 'fs'"
-> std.fs.Dir/File moved to std.Io.Dir/File

"expected 2 arguments, found 1" on file.close() / read() etc.
-> File/Dir methods need io parameter now

"no member named 'indexOf'" / "no member named 'indexOfScalar'"
-> Renamed to find/findScalar (entire indexOf family)

"no member named 'environ' in struct 'os'"
-> std.os.environ removed - use init.environ_map

"no member named 'argsAlloc'" or argsAlloc deprecation
-> Plumb args via init.minimal.args from main

"no member named 'getCwd'" or "getCwdAlloc"
-> Renamed to process.currentPath / currentPathAlloc

"no member named 'init'" on Child / Mutex / Pool
-> Child.init+spawn -> process.spawn; Thread.* -> Io.*

"no member named 'Pool' in struct 'Thread'"
-> std.Thread.Pool removed - use std.Io.Group with .async

"no member named 'ThreadSafeAllocator' in struct 'heap'"
-> Removed - ArenaAllocator is lock-free thread-safe now

"no member named 'Instant'" / "Timer" in struct 'time'
-> Use std.Io.Timestamp; Timestamp.now() replaces timestamp()

"@Type call removed; use @Int/@Struct/@Enum/..."
-> @Type was split into 8 separate builtins

"runtime value cannot be used to index a vector"
-> Coerce vector to array before indexing

"returning address of expired local variable"
-> return &local_var no longer accepted; rewrite

"no member named 'fixedBufferStream' in struct 'io'"
-> Use std.Io.Reader.fixed / std.Io.Writer.fixed

"no member named 'Formatter' in struct 'fmt'"
-> Renamed to std.fmt.Alt

"unable to find dependency 'fingerprint' in zon"
-> build.zig.zon now requires fingerprint on every dep

"name must be enum literal, found string"
-> Dependency names in zon are enum literals (.foo not "foo")
```

## Critical Code Patterns

### Juicy Main - Memorize the Three Signatures

```zig
// 1. Bare main - no CLI args, no env access
pub fn main() void { ... }
pub fn main() !void { ... }

// 2. Init.Minimal - raw args + environ only
pub fn main(init: std.process.Init.Minimal) !void {
    var args = init.args.iterate();
    while (args.next()) |arg| { ... }
}

// 3. Full Init - gpa, io, arena, environ_map, preopens, minimal
pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;
    const arena = init.arena.allocator();
    _ = gpa; _ = arena;

    try std.Io.File.stdout().writeStreamingAll(io, "Hello\n");
}
```

The runtime detects which signature you used and supplies the
matching value. Prefer the full `Init` for any non-trivial
program; you get the gpa, an arena, an `Io`, the environ map,
and preopens for free.

### Stdout / Stderr Pattern

```zig
// WRONG (0.15 training)
var stdout_buffer: [8192]u8 = undefined;
var stdout_writer = std.fs.File.stdout().writerStreaming(&stdout_buffer);
const stdout = &stdout_writer.interface;

// RIGHT (0.16, buffered, O_APPEND-safe) -- VERIFIED against 0.16.0
pub fn main(init: std.process.Init) !void {
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer =
        std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};

    try stdout.print("Hello {s}\n", .{name});
}

// Unbuffered shortcut - fine for one-off prints
try std.Io.File.stdout().writeStreamingAll(init.io, "Hello\n");

// stderr diagnostic output - no Io needed
std.debug.print("debug: {s}\n", .{msg});
```

Use `writerStreaming` (not `writer`) for stdout/stderr.
`writerStreaming` runs in `.streaming` mode (regular write
syscalls, O_APPEND respected). `writer` runs in `.positional`
mode (uses pwritev at offset 0, ignores O_APPEND, breaks
shell `>>` redirects on macOS). Same lesson as 0.15.

Public types: `std.Io.File.Writer` (the buffer-holding struct)
and `std.Io.Writer` (the interface, accessed via `.interface`).
Reader/writer have **symmetric** signatures —
`pub fn reader(file: File, io: Io, buffer: []u8) Reader` and
`pub fn writer(file: File, io: Io, buffer: []u8) Writer`.
Both take `io`. (Earlier release-notes examples that show
`file.reader(&.{})` predate the final API.)

### `std.fs` -> `std.Io` Namespace Move

```zig
// WRONG (0.15 training)
const file = try std.fs.cwd().openFile("hello.txt", .{});
defer file.close();
const data = try file.readToEndAlloc(allocator, 1024);

// RIGHT (0.16)
const file = try std.Io.Dir.cwd().openFile(io, "hello.txt", .{});
defer file.close(io);

var read_buffer: [4096]u8 = undefined;
var file_reader = file.reader(io, &read_buffer);
const data = try file_reader.interface
    .allocRemaining(allocator, .limited(1024));
```

Most filesystem methods just gain an `io` first parameter.
Some signatures reshaped (`readFileAlloc`, `readToEndAlloc`,
atomic-file API, `setTimestamps`). Trailing-Z/W variants
(`renameZ`, `realpathW`, etc.) all removed.

### Method Renames on Dir / File

```zig
// Old              -> New
dir.makeDir         -> dir.createDir
dir.makePath        -> dir.createDirPath
dir.makeOpenDir     -> dir.createDirPathOpen
dir.atomicSymLink   -> dir.symLinkAtomic
dir.chmod           -> dir.setPermissions
dir.realpath        -> dir.realPathFile

file.setEndPos      -> file.setLength
file.getEndPos      -> file.length
file.read / readv   -> file.readStreaming
file.pread/preadv   -> file.readPositional
file.write/writev   -> file.writeStreaming
file.writeAll       -> file.writeStreamingAll
file.pwrite/pwriteAll -> file.writePositional/All
file.chmod          -> file.setPermissions
file.updateTimes    -> file.setTimestamps / setTimestampsNow
File.Mode           -> File.Permissions
```

### `indexOf*` -> `find*` Rename

```zig
// WRONG (0.15 training)
const i = std.mem.indexOf(u8, haystack, "needle");
const j = std.mem.indexOfScalar(u8, s, ' ');
const k = std.mem.lastIndexOf(u8, s, "x");

// RIGHT (0.16)
const i = std.mem.find(u8, haystack, "needle");
const j = std.mem.findScalar(u8, s, ' ');
const k = std.mem.findLast(u8, s, "x");
```

The full rename map: `indexOf*`/`lastIndexOf*` -> `find*`/
`findLast*` (Pos, Scalar, Any, Linear all keep their suffixes).
The release notes describe the rule but not a literal table -
verify name-by-name against `lib/std/mem.zig` if a lookup fails
to compile.

New `cut*` family added: `cut`, `cutPrefix`, `cutSuffix`,
`cutScalar`, `cutLast`, `cutScalarLast` - splits at first/last
delimiter, returns `(prefix, suffix)` pair (Go's
`strings.Cut`). (Note: `Last` comes after `Scalar`, not
before — `cutScalarLast`, not `cutLastScalar`. Same convention
applies to `findScalarLast`.)

### Args & Environment

```zig
// WRONG (0.15 training)
const args = try std.process.argsAlloc(allocator);
defer std.process.argsFree(allocator, args);
const home = std.os.getenv("HOME"); // global access

// RIGHT (0.16) - iterate
pub fn main(init: std.process.Init.Minimal) !void {
    var it = init.args.iterate();
    while (it.next()) |arg| { ... }
}

// RIGHT (0.16) - slice
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    for (args) |arg| { ... }

    // env via the full Init's environ_map
    for (init.environ_map.keys(), init.environ_map.values()) |k, v| {
        std.log.info("{s}={s}", .{ k, v });
    }
    // or single lookup
    const home = init.minimal.environ.getPosix("HOME"); // ?[]const u8
}
```

`std.os.environ` is GONE. Functions that need env access take
a `*const std.process.Environ.Map` parameter, plumbed from
`main` like an `Allocator`.

### Spawning Child Processes

```zig
// WRONG (0.15 training)
var child = std.process.Child.init(argv, gpa);
child.stdin_behavior = .Pipe;
child.stdout_behavior = .Pipe;
try child.spawn();

// RIGHT (0.16)
var child = try std.process.spawn(io, .{
    .argv = argv,
    .stdin = .pipe,
    .stdout = .pipe,
    .stderr = .pipe,
});

// One-shot run:
const result = try std.process.run(allocator, io, .{ .argv = argv });

// Replace process image (was execv):
const err = std.process.replace(io, .{ .argv = argv });
```

### Sync Primitives -> `std.Io.*`

```zig
// Old                       -> New
std.Thread.Mutex            -> std.Io.Mutex
std.Thread.Condition        -> std.Io.Condition
std.Thread.Semaphore        -> std.Io.Semaphore
std.Thread.RwLock           -> std.Io.RwLock
std.Thread.Futex            -> std.Io.Futex
std.Thread.ResetEvent       -> std.Io.Event
std.Thread.WaitGroup        -> std.Io.Group
std.Thread.Pool             -> REMOVED (use std.Io.Group)
std.Thread.Mutex.Recursive  -> REMOVED
std.once                    -> REMOVED
```

Sync APIs moved so contended primitives can integrate with the
chosen `Io` backend (block a thread on `Io.Threaded`, switch
stacks on `Io.Evented`). Atomic / lock-free primitives don't
need `Io`.

```zig
// WRONG (0.15 training - thread pool)
fn doWork(pool: *std.Thread.Pool) void {
    var wg: std.Thread.WaitGroup = .{};
    pool.spawnWg(&wg, work, .{ &wg });
    wg.wait();
}

// RIGHT (0.16 - Io.Group)
fn doWork(io: std.Io) !void {
    var g: std.Io.Group = .init;
    errdefer g.cancel(io);
    g.async(io, work, .{io});
    try g.await(io);
}
```

### Random / Time

```zig
// WRONG (0.15 training)
var buf: [32]u8 = undefined;
std.crypto.random.bytes(&buf);
const t = std.time.timestamp();
var timer = try std.time.Timer.start();

// RIGHT (0.16)
var buf: [32]u8 = undefined;
io.random(&buf);                         // PRNG
io.randomSecure(&buf);                   // OS entropy, may fail
const t = std.Io.Timestamp.now(io);
// Timer/Instant collapsed into Timestamp - check stdlib for
// elapsed-since helpers
```

### `@Type` Split Into Eight Builtins

```zig
// WRONG (0.15 training)
const U10 = @Type(.{ .int = .{ .signedness = .unsigned, .bits = 10 } });
const Lit = @Type(.enum_literal);
const T = @Type(.{ .@"struct" = .{
    .layout = .auto, .fields = ..., .is_tuple = true, ...,
} });

// RIGHT (0.16)
const U10 = @Int(.unsigned, 10);
const Lit = @EnumLiteral();
const T = @Tuple(&.{ u32, [2]f64 });
```

The eight new builtins: `@Int`, `@EnumLiteral`, `@Tuple`,
`@Pointer`, `@Fn`, `@Struct`, `@Union`, `@Enum`. There is NO
`@Float`, `@Array`, `@Optional`, `@ErrorUnion`, `@ErrorSet` -
write the literal type instead (`f32`, `[N]T`, `?T`, `E!T`,
`error{...}`).

`std.meta.Int` and `std.meta.Tuple` are deprecated. Tuple
types with `comptime` fields can no longer be reified.

### `std.io.fixedBufferStream` Removed

```zig
// WRONG (0.15 training)
var fbs = std.io.fixedBufferStream(data);
const reader = fbs.reader();

// RIGHT (0.16)
var reader: std.Io.Reader = .fixed(data);
var writer: std.Io.Writer = .fixed(buffer);
```

Also removed: `GenericReader`, `AnyReader`, `GenericWriter`,
`AnyWriter`, `null_writer`, `CountingReader`. Use the concrete
`std.Io.Reader` / `std.Io.Writer` types.

### Containers - Managed Hash Maps Removed

```zig
// WRONG (0.15 training)
var map: std.AutoArrayHashMap(K, V) = .init(allocator);
defer map.deinit();

// RIGHT (0.16)
var map: std.array_hash_map.Auto(K, V) = .empty;
defer map.deinit(allocator);
```

The previously-Unmanaged variants got the short names:
`array_hash_map.Auto`, `array_hash_map.String`,
`array_hash_map.Custom`. Pass `allocator` to each method.

`std.SegmentedList` is GONE with no replacement. Fall back to
`ArrayListUnmanaged` or vendor the 0.15 implementation.

### PriorityQueue / PriorityDequeue

```zig
// WRONG (0.15 training)
var q = std.PriorityQueue(u32, void, lt).init(allocator, {});
defer q.deinit();
try q.add(42);
const x = q.remove();

// RIGHT (0.16)
var q: std.PriorityQueue(u32, void, lt) = .empty;
defer q.deinit(allocator);
try q.push(allocator, 42);
const x = q.pop();
```

Renames: `add*` -> `push*`, `remove*` -> `pop*`, `removeMin/Max`
-> `popMin/Max`, `removeIndex` -> `popIndex`.

### `@cImport` Deprecated -> `b.addTranslateC`

```zig
// WRONG (0.15 training - in source)
const c = @cImport({ @cInclude("glfw.h"); });

// RIGHT (0.16 - in build.zig)
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
        .imports = &.{ .{
            .name = "c",
            .module = translate_c.createModule(),
        } },
    }),
});
```

In the source: `const c = @import("c");`.

### `build.zig.zon` Required Fields

```zig
// 0.16 requirements (zig build will fail otherwise):
.{
    .name = .my_project,            // enum literal, NOT string
    .version = "0.1.0",
    .fingerprint = 0x1234567890abcdef,  // required
    .dependencies = .{
        .some_dep = .{
            .url = "...",
            .hash = "...",
            .fingerprint = 0xdeadbeef,  // required on each dep
        },
    },
    .paths = .{ "" },
}
```

Same fingerprint + same version + different hash anywhere in
the dependency tree is now an error. Legacy hash format is
removed.

### Vector Indexing

```zig
// WRONG (0.15 training)
for (0..vector_len) |i| { _ = my_vector[i]; }

// RIGHT (0.16) - coerce to array first
const info = @typeInfo(@TypeOf(my_vector)).vector;
const arr: [info.len]info.child = my_vector;
for (&arr) |elem| { _ = elem; }
```

Runtime indexing of a vector is forbidden. Indices must be
comptime-known, or coerce the vector to an array first.

### Trivial Local-Address Returns

```zig
// WRONG (0.15 sometimes accepted, 0.16 errors)
fn foo() *i32 {
    var x: i32 = 1234;
    return &x;
}

// RIGHT - if you genuinely want an invalid pointer:
fn foo() *i32 {
    return undefined;
}
```

### Optional `File.Stat.atime`

```zig
// WRONG (0.15 training)
const t = stat.atime;

// RIGHT (0.16) - some filesystems refuse atime
const t = stat.atime orelse return error.FileAccessTimeUnavailable;
```

### `setTimestamps` Reshape

```zig
// 0.15
try file.setTimestamps(io, src_stat.atime, src_stat.mtime);

// 0.16 - struct param, .init() per field
try file.setTimestamps(io, .{
    .access_timestamp = .init(src_stat.atime),
    .modify_timestamp = .init(src_stat.mtime),
});
```

### Allocators

```zig
// WRONG (0.15 training)
var tsa = std.heap.ThreadSafeAllocator{ .child_allocator = base };
const allocator = tsa.allocator();

// RIGHT (0.16) - ArenaAllocator is lock-free thread-safe
var arena = std.heap.ArenaAllocator.init(base);
defer arena.deinit();
const allocator = arena.allocator();
```

`std.heap.ThreadSafeAllocator` is GONE. Wrapping is no longer
needed for arenas. New: `MemoryPoolUnmanaged`,
`MemoryPoolAlignedUnmanaged`, `MemoryPoolExtraUnmanaged`.

### Error Renames

```zig
// 0.15 -> 0.16
error.RenameAcrossMountPoints      -> error.CrossDevice
error.NotSameFileSystem            -> error.CrossDevice
error.SharingViolation             -> error.FileBusy
error.EnvironmentVariableNotFound  -> error.EnvironmentVariableMissing
error.FileTooBig (readFileAlloc)   -> error.StreamTooLong

// Behavior change:
// Dir.rename over non-empty dir: PathAlreadyExists -> DirNotEmpty
```

### Build System

```zig
// REMOVED in 0.16:
// - Build.makeTempPath  (use b.addTempFiles / b.tmpPath())
// - RemoveDir step      (had no valid purpose)
// - --prominent-compile-errors  (use --error-style minimal)
// - std.builtin.subsystem        (use std.zig.Subsystem)

// New flags:
//   --error-style {verbose,minimal,verbose_clear,minimal_clear}
//   --multiline-errors {indent,newline,none}
//   --test-timeout 500ms
//   --fork=/path/to/local/checkout  (override package locally)
```

Packages now fetch into `zig-pkg/` next to `build.zig` (was
global `$ZIG_CACHE/p/$HASH`). Don't commit `zig-pkg/`.

## When You Don't Have an `Io`

Plumb it from `main` like an `Allocator`. As an escape hatch
(release notes call it "non-ideal"):

```zig
var threaded: std.Io.Threaded = .init_single_threaded;
const io = threaded.io();
```

In tests there's a free one: `std.testing.io` (parallel to
`std.testing.allocator`).

## Migration Order (When Upgrading 0.15 -> 0.16)

1. Change `main` signature to take `std.process.Init`.
2. Replace stdout/stderr pattern with
   `std.Io.File.stdout().writeStreamingAll(io, ...)`.
3. Add `io` parameter to every `std.fs.File`/`Dir` call.
4. Move `std.fs.*` -> `std.Io.*`.
5. Search-and-replace `indexOf*` -> `find*`.
6. Replace `std.os.environ` reads with plumbed
   `*const Environ.Map`.
7. Replace `std.process.argsAlloc` with
   `init.minimal.args.toSlice(arena)`.
8. Move `std.Thread.{Mutex,...}` -> `std.Io.{Mutex,...}`.
9. Replace `std.Thread.Pool` with `std.Io.Group`.
10. Replace managed hash maps with `array_hash_map.{Auto,String}`.
11. Replace `@Type(...)` calls with `@Int`/`@Struct`/etc.
12. Add `fingerprint` to every dependency in `build.zig.zon`.
13. Convert dependency `name` strings to enum literals.

## Reference Order When Stuck

1. Grep this file for the symbol or error message.
2. Grep the official 0.16.0 release notes.
3. Grep the 0.16.0 language reference.
4. Last resort: read `lib/std/Io/...` source in your installed
   Zig. The lang ref is incomplete; the source isn't.

The language changed fundamentally - again. Your instincts
are wrong, especially around I/O, process state, threads, and
the filesystem. Always verify.
