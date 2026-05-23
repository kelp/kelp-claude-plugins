## Zig 0.16 Training Corrections

Your Zig training is outdated. This project uses Zig 0.16, which is a
**Writergate-scale churn release** -- "I/O as an Interface" plus a
filesystem move from `std.fs` to `std.Io`. Most of what you learned
about touching the outside world is now wrong.

### The Patterns You Get Wrong

Before writing ANY Zig code, internalize these corrections:

1. **`pub fn main() !void`** -- still legal but blind. Use
   `pub fn main(init: std.process.Init) !void` ("Juicy Main") to get
   `gpa`, `io`, `arena`, `environ_map`, `preopens`, plus
   `init.minimal.args` / `init.minimal.environ`.
2. **`std.io`** -- renamed to `std.Io` (capitalized). The old name is
   deprecated.
3. **`std.fs.File` / `std.fs.Dir`** -- moved to `std.Io.File` /
   `std.Io.Dir`. `std.fs.cwd()` -> `std.Io.Dir.cwd()`.
4. **Every blocking call now takes `io`**: `file.close(io)`,
   `file.writeStreaming(io, ...)`, `dir.createDir(io, name)`,
   `file.length(io)`, `file.setPermissions(io, ...)`.
5. **`Dir.makeDir` / `makePath`** -- renamed to `createDir` /
   `createDirPath`.
6. **`File.write/writeAll`** -- renamed to `writeStreaming` /
   `writeStreamingAll`. Positional variants are `writePositional` /
   `writePositionalAll`.
7. **`std.mem.indexOf*`** -- renamed to `find*` (`indexOf` -> `find`,
   `indexOfScalar` -> `findScalar`, `lastIndexOf` -> `findLast`,
   `lastIndexOfScalar` -> `findScalarLast`). Note `Last` comes after
   `Scalar`.
8. **`std.os.environ`** -- gone. Use `init.environ_map` plumbed
   through from `main`.
9. **`std.process.argsAlloc(allocator)`** -- gone. Use
   `init.minimal.args.toSlice(allocator)` or the iterator
   `init.minimal.args.iterate()`.
10. **`std.process.Child.init(...).spawn()`** -- gone. Use
    `std.process.spawn(io, .{ .argv, .stdin, .stdout, .stderr })`.
11. **`std.process.getCwd` / `getCwdAlloc`** -- renamed to
    `std.process.currentPath(io, buf)` /
    `std.process.currentPathAlloc(io, allocator)`.
12. **`std.posix.PROT.READ | std.posix.PROT.WRITE`** -- replaced by
    type-safe struct: `.{ .READ = true, .WRITE = true }`.
13. **`std.Thread.Mutex` / `Condition` / `Semaphore` / `WaitGroup`**
    -- moved to `std.Io.Mutex` / `Io.Condition` / `Io.Semaphore` /
    `Io.Group`. `std.Thread.Pool` removed -- use `std.Io.async` /
    `std.Io.Group.async`.
14. **`std.crypto.random.bytes(&buf)`** -- replaced by
    `io.random(&buf)`. Use `io.randomSecure(&buf)` when entropy must
    bypass any in-process RNG state.
15. **`std.time.Instant` / `Timer` / `timestamp`** -- collapsed into
    `std.Io.Timestamp` (one type) and `std.Io.Timestamp.now`.
16. **`@Type(.{ .int = ... })`** -- replaced by eight new builtins:
    `@Int(.unsigned, 10)`, `@EnumLiteral()`, `@Tuple`, `@Pointer`,
    `@Fn`, `@Struct`, `@Union`, `@Enum`. There is no `@Float`,
    `@Array`, `@Optional`, or `@ErrorUnion` -- write the literal type.
17. **`@cImport({ @cInclude(...) })`** -- deprecated. Use
    `b.addTranslateC(...)` in `build.zig`.
18. **`error.RenameAcrossMountPoints` / `NotSameFileSystem`** ->
    `error.CrossDevice`. **`error.SharingViolation`** ->
    `error.FileBusy`. **`error.FileTooBig` (readFileAlloc)** ->
    `error.StreamTooLong`.
19. **`Dir.rename` on non-empty destination** -- returns
    `error.DirNotEmpty`, not `error.PathAlreadyExists`.
20. **Managed hash maps** -- gone. `AutoArrayHashMap` ->
    `std.array_hash_map.Auto`. Same for `StringArrayHashMap` ->
    `String`, `ArrayHashMap` -> `Custom`. Use `.empty` initializer.
21. **`std.BoundedArray`** -- still gone (from 0.15). Use
    `ArrayListUnmanaged.initBuffer`.
22. **`usingnamespace`** -- still gone. Use zero-bit fields with
    `@fieldParentPtr`.
23. **`async` / `await` keywords** -- still gone. Concurrency now via
    `std.Io.async` / `std.Io.Group.async`.

### "Juicy Main" -- Memorize This

```zig
const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;
    const arena = init.arena.allocator();
    _ = gpa; _ = arena;

    try std.Io.File.stdout().writeStreamingAll(io, "Hello, world!\n");

    const args = try init.minimal.args.toSlice(init.arena.allocator());
    for (args) |arg| std.log.info("arg: {s}", .{arg});
}
```

`std.process.Init` bundles a pre-initialized allocator (`gpa`), an
`Io` instance (`io`), an `arena`, an `environ_map`, and `preopens`.
The nested `init.minimal` carries the raw `args` and `environ`.

If you genuinely don't need args/env, `pub fn main() !void` still
works. If you need only raw argv/environ without an allocator,
`pub fn main(init: std.process.Init.Minimal) !void` is the middle
option.

### Buffered stdout/stderr (Writergate, 0.16 edition)

```zig
pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer =
        std.Io.File.stdout().writerStreaming(io, &stdout_buf);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};

    var stderr_buf: [4096]u8 = undefined;
    var stderr_writer =
        std.Io.File.stderr().writerStreaming(io, &stderr_buf);
    const stderr = &stderr_writer.interface;
    defer stderr.flush() catch {};

    try stdout.print("count: {d}\n", .{42});
    _ = stderr;
}
```

Use `writerStreaming` (not `writer`) for stdout/stderr -- the
positional `writer()` form ignores O_APPEND and breaks shell `>>`
redirects on macOS. Reader and writer are symmetric:
`pub fn reader(file, io, buffer) Reader` /
`pub fn writer(file, io, buffer) Writer`.

### When You Don't Have an `Io`

Plumb it through. If you absolutely cannot, the escape hatch is:

```zig
var threaded: std.Io.Threaded = .init_single_threaded;
const io = threaded.io();
```

Treat this like `std.heap.page_allocator` -- a last resort.

### Tests Get a Free `Io`

```zig
test "demo" {
    const io = std.testing.io;
    const file = try std.Io.Dir.cwd().openFile(io, "hello.txt", .{});
    defer file.close(io);
}
```

Same shape as `std.testing.allocator`.

### `ArrayList` and Hash Maps Use `.empty`

```zig
var list: std.ArrayList(u8) = .empty;
defer list.deinit(gpa);
try list.append(gpa, 'a');

var map: std.array_hash_map.Auto(K, V) = .empty;
defer map.deinit(gpa);
```

The "managed" forms with bound allocators are gone -- pass the
allocator into every mutating method and `deinit`.

### `build.zig` Pattern

`addExecutable` still wraps the source in a module. Translate-C
moved into the build graph:

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

For C interop, replace `@cImport` blocks with `b.addTranslateC(...)`
in `build.zig` and `@import("c")` in the source.

### Shell Rules

Run commands exactly as shown. Do NOT append shell syntax
like `2>&1`, `; echo "EXIT: $?"`, or pipe redirections.
The Bash tool already captures stdout, stderr, and exit codes.

### Quick Lookup

When you hit a compile error, run
`/zig-claude-kit:zig-patterns` for the full reference table,
code patterns, and error message diagnostics.
