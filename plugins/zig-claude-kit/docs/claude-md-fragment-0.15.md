## Zig 0.15.x Training Corrections

Your Zig training is outdated. This project uses Zig 0.15.x
with breaking changes that affect code you generate by default.

### The Patterns You Get Wrong

Before writing ANY Zig code, internalize these corrections:

1. `std.io.getStdOut()` / `getStdErr()` -- **removed**
   (Writergate). Use buffered writer pattern.
2. `build.zig` uses `.root_module = b.createModule(...)` --
   not bare `.root_source_file`.
3. Format method signature changed; `{}` requires `{f}` to
   call format methods.
4. `usingnamespace` -- **removed** from language entirely.
5. `std.BoundedArray` -- **removed**. Use
   `ArrayListUnmanaged.initBuffer`.
6. `std.ArrayList(T).init(allocator)` -- **removed**. Use
   `std.ArrayListUnmanaged(T){}` with allocator per call.
7. `/` on runtime signed integers -- **compile error**. Use
   `@divTrunc`, `@divFloor`, or `@divExact`.
8. `std.mem.tokenize` -- **renamed**. Use `tokenizeAny`,
   `tokenizeScalar`, or `tokenizeSequence`.
9. `std.process.args()` -- **changed**. Use
   `argsAlloc(allocator)`, returns owned slice, must free.
10. `for (items) |item, i|` -- **compile error**. Use
    `for (items, 0..) |item, i|` with explicit index range.
11. `async` / `await` -- **removed** from the language.
12. `std.json.Parser` -- **redesigned**. Use
    `std.json.parseFromSlice(T, allocator, text, .{})`.

### I/O Pattern (Writergate) -- Memorize This

```zig
// WRONG: std.io.getStdOut().writer()
// RIGHT:
var stdout_buffer: [4096]u8 = undefined;
var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
const stdout = &stdout_writer.interface;
defer stdout.flush() catch {};

try stdout.print("Hello, {s}\n", .{name});
```

Always `defer flush() catch {}` or data is lost.

Use `writerStreaming()` instead of `writer()` when output
must respect O_APPEND (e.g. shell `>>` redirects).

### build.zig Pattern

```zig
// WRONG:
// const exe = b.addExecutable(.{
//     .name = "app",
//     .root_source_file = b.path("src/main.zig"),
//     .target = target,
//     .optimize = optimize,
// });

// RIGHT:
const exe = b.addExecutable(.{
    .name = "app",
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    }),
});
```

### Shell Rules

Run commands exactly as shown. Do NOT append shell syntax
like `2>&1`, `; echo "EXIT: $?"`, or pipe redirections.
The Bash tool already captures stdout, stderr, and exit
codes.

### Quick Lookup

When you hit a compile error, run
`/zig-claude-kit:zig-patterns` for the full reference table,
code patterns, and error message diagnostics.
