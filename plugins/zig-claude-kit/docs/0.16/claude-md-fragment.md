## Zig 0.16.x Training Corrections

Your Zig training is outdated. This project uses Zig 0.16.x
with breaking changes that affect code you generate by default.
0.16 is a Writergate-scale release — every blocking API now
takes an `Io` parameter, `std.fs` moved to `std.Io`, process
state is no longer global, and `std.mem.indexOf*` was renamed
to `find*`.

### The Patterns You Get Wrong

Before writing ANY Zig code, internalize these corrections:

1. **`io: Io` parameter on every blocking API** — `file.close()`
   → `file.close(io)`, `file.write(...)` →
   `file.writeStreaming(io, ...)`, etc.
2. **`std.fs.*` → `std.Io.*`** — `std.fs.File` → `std.Io.File`,
   `std.fs.Dir` → `std.Io.Dir`, `std.fs.cwd()` →
   `std.Io.Dir.cwd()`. Trailing `*Z`/`*W` variants removed.
3. **`std.mem.indexOf*` → `find*`** — `indexOf` → `find`,
   `indexOfScalar` → `findScalar`, `lastIndexOf` → `findLast`,
   etc. New `cut*` family: `cut`, `cutPrefix`, `cutSuffix`.
4. **Args & env are no longer global** — `std.os.environ` is
   gone. Use `pub fn main(init: std.process.Init) !void` and
   route `init.environ_map`/`init.minimal.args` to callees.
5. **`std.process.getCwd*`** → `std.process.currentPath*`
   (now takes `io`).
6. **`std.process.Child.init/spawn`** → `std.process.spawn(io,
   .{ .argv, .stdin, .stdout, .stderr })`.
7. **`std.Thread.{Mutex,Condition,ResetEvent,WaitGroup,...}`**
   → `std.Io.{Mutex,Condition,Event,Group,...}`.
   `std.Thread.Pool` removed; use `std.Io.async` / `Group.async`.
8. **`std.heap.ThreadSafeAllocator` removed.**
   `std.heap.ArenaAllocator` is now lock-free thread-safe;
   no wrapper needed.
9. **Managed `ArrayHashMap` family removed** — use
   `array_hash_map.{Auto,String,Custom}`.
10. **`@Type(.{ .int = ... })`** → `@Int(.unsigned, 10)` (and
    7 other concrete builtins: `@Struct`, `@Union`, `@Enum`,
    `@EnumLiteral`, `@Tuple`, `@Pointer`, `@Fn`).
11. **`@cImport` deprecated** — use `b.addTranslateC(...)` in
    `build.zig`.
12. **`File.Stat.atime` is now optional** — must
    `orelse error.FileAccessTimeUnavailable`.
13. **`std.io.fixedBufferStream` removed** — use
    `var w: std.Io.Writer = .fixed(buf);` /
    `var r: std.Io.Reader = .fixed(data);`.
14. **`std.crypto.random.bytes(&buf)`** → `io.random(&buf)`.
15. **`std.time.Instant`/`Timer`** → `std.Io.Timestamp`.
16. **Error renames:** `RenameAcrossMountPoints`/`NotSameFileSystem`
    → `CrossDevice`. `SharingViolation` → `FileBusy`.
    `EnvironmentVariableNotFound` → `EnvironmentVariableMissing`.
    `FileTooBig` → `StreamTooLong`.
17. **Runtime vector indexing forbidden** — coerce to array
    first.
18. **Returning `&local_var` for trivial cases is now an
    error.**

The 0.15.x corrections also still apply: `usingnamespace` and
`async`/`await` remain removed; `ArrayList` is still unmanaged
(`.empty` is the new init form, allocator on every method);
signed division still requires `@divTrunc`/`@rem`; `{f}` is
still required to call format methods; for-loops still need
explicit index syntax (`for (items, 0..) |item, i|`); JSON is
still `std.json.parseFromSlice`; `tokenize` is still split
into `tokenizeAny`/`tokenizeScalar`/`tokenizeSequence`.

### I/O Pattern (Juicy Main) -- Memorize This

```zig
// WRONG (your training): std.io.getStdOut().writer()
// WRONG (0.15-era):       std.fs.File.stdout().writerStreaming(&buf)
// RIGHT (0.16, buffered, O_APPEND-safe — verified against 0.16.0):
pub fn main(init: std.process.Init) !void {
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer =
        std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};

    try stdout.print("Hello, {s}\n", .{name});
}

// Unbuffered shortcut — fine for one-off prints:
//     try std.Io.File.stdout().writeStreamingAll(init.io, "Hello\n");
```

Always `defer flush() catch {}` on buffered writers or data
is lost. Use `writerStreaming` (not `writer`) for stdout/stderr:
`writer` runs in `.positional` mode and silently ignores
O_APPEND, breaking shell `>>` redirects on macOS. Every blocking
API needs `io` — forgetting it is the single most common 0.16
mistake.

### Args (no longer global)

```zig
pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);
    for (args[1..]) |arg| { _ = arg; }
}
```

For utilities that don't need `gpa`/`io`, use
`pub fn main(init: std.process.Init.Minimal) !void` — exposes
just `args` and `environ`.

### build.zig Pattern (unchanged from 0.15)

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

`build.zig.zon` now requires a `fingerprint` field on each
dependency, and `name` must be an enum literal (not a string).

### Shell Rules

Run commands exactly as shown. Do NOT append shell syntax
like `2>&1`, `; echo "EXIT: $?"`, or pipe redirections.
The Bash tool already captures stdout, stderr, and exit
codes.

### Quick Lookup

When you hit a compile error, run
`/zig-claude-kit:zig-patterns` for the full reference table,
code patterns, and error message diagnostics.
