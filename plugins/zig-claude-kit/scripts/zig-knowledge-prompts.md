# Zig Knowledge Prompts

Test Claude's base Zig knowledge by pasting these prompts into
a fresh conversation with NO project context. Save each response
to the numbered .zig file, then run the test harness.

Probes 01–14 are version-agnostic in framing; the model's answer
either compiles against the target Zig or it doesn't. Probes
15–18 are 0.16-specific (run with `--version 0.16`).

## How to Test

1. Open a fresh Claude conversation (no project loaded)
2. For each prompt below, ask Claude the question
3. Save the code it produces to `probes/NN_name.zig`
4. Run: `./scripts/zig-knowledge-test.sh probes/`
   (set `ZIG=/path/to/zig` to test against a specific version)
5. Results show which patterns Claude gets wrong

## Running against both versions

```bash
make eval-015   # original 14 probes against zig on PATH
make eval-016   # 18 probes against Zig 0.16.0 (auto-locates
                # via `mise where zig@0.16.0`, or set ZIG=...)
```

## Prompts

### 01 - stdout (Writergate)

> Write a Zig program that prints "hello world" to stdout.
> Just the code, no explanation. Use the standard library.

Tests: Does Claude use `std.io.getStdOut()` (broken) or the
buffered writer pattern (correct)?

### 02 - stderr

> Write a Zig function that prints an error message to stderr.
> Just the code, no explanation.

Tests: Does Claude use `std.io.getStdErr()` (broken) or the
buffered writer pattern (correct)?

### 03 - ArrayList

> Write a Zig test that creates an ArrayList of u32, appends
> three values, and checks the length is 3. Just the code.

Tests: Does Claude use `.init(allocator)` managed pattern or
`ArrayListUnmanaged` with allocator-per-call?

### 04 - BoundedArray

> Write a Zig function that uses a stack-allocated bounded
> array (max 64 elements) of u8. Append a few values and
> return the slice. Just the code.

Tests: Does Claude use `std.BoundedArray` (removed) or
`ArrayListUnmanaged.initBuffer` (correct)?

### 05 - tokenize

> Write a Zig function that splits a string by whitespace and
> returns the token count. Just the code.

Tests: Does Claude use `std.mem.tokenize` (old name) or
`std.mem.tokenizeAny`/`tokenizeScalar` (current)?

### 06 - testing

> Write a Zig test that compares two strings for equality
> using the standard testing library. Just the code.

Tests: Does Claude use `expectEqualStrings` (still works) or
`expectEqualSlices(u8, ...)` (also works)?

### 07 - process args

> Write a Zig program that prints each command-line argument
> on its own line. Just the code.

Tests: Does Claude use `std.process.args()` (still works) or
`std.process.argsAlloc` (also works)?

### 08 - JSON parsing

> Write a Zig test that parses the JSON string
> `{"name":"alice","age":30}` into a struct and checks the
> values. Just the code.

Tests: Does Claude use `std.json.Parser` (removed) or
`std.json.parseFromSlice` (correct)?

### 09 - format method

> Write a Zig struct with an x:i32 field that implements the
> format method so it can be printed with std.fmt. Include a
> test that formats it to a buffer. Just the code.

Tests: Does Claude use old format signature with `comptime fmt,
options, writer: anytype` (broken) or new signature with
`writer: *std.Io.Writer` (correct)?

### 10 - usingnamespace

> Write a Zig mixin pattern where a struct gains methods from
> another type. Just the code.

Tests: Does Claude use `usingnamespace` (removed) or zero-bit
field with `@fieldParentPtr` (correct)?

### 11 - division

> Write a Zig function that takes two i32 parameters and
> returns their integer quotient. Just the code.

Tests: Does Claude use `a / b` (fails for runtime signed ints)
or `@divTrunc(a, b)` (correct)?

### 12 - for loop with index

> Write a Zig function that iterates over a slice and prints
> each element with its index. Just the code.

Tests: Does Claude use `for (items) |item, i|` (old syntax) or
`for (items, 0..) |item, i|` (correct)?

### 13 - build.zig executable

> Write a Zig build.zig file that builds an executable called
> "hello" from src/main.zig. Just the code.

Tests: Does Claude use `.root_source_file` directly (old) or
`.root_module = b.createModule(...)` (correct)?

### 14 - async/await

> Write a Zig program that runs two tasks concurrently using
> async/await. Just the code.

Tests: Does Claude try to use `async`/`await` (removed) or
explain they don't exist?

## 0.16-specific Prompts (run with `--version 0.16`)

### 15 - file I/O

> Write a Zig function that opens a file 'data.txt', reads
> the entire contents into a buffer, and closes the file.
> Just the code.

Tests: Does Claude use `std.fs.cwd().openFile(...)` (0.15)
or `std.Io.Dir.cwd().openFile(io, ...)` (0.16) and thread the
`io` parameter through `read`/`close`?

### 16 - indexOf vs find

> Write a Zig function that finds the first occurrence of the
> substring "foo" in a haystack []const u8 and returns its
> index, or null. Use the standard library. Just the code.

Tests: Does Claude use `std.mem.indexOf` (renamed in 0.16) or
`std.mem.find` (correct in 0.16)?

### 17 - child process

> Write a Zig function that runs the 'ls' command as a
> subprocess and captures its stdout into a buffer. Just the
> code.

Tests: Does Claude use `std.process.Child.init/spawn` (0.15)
or `std.process.spawn(io, .{...})` / `process.run(...)` (0.16)?

### 18 - thread mutex

> Write a Zig program that uses a Mutex from the standard
> library to protect shared state across two threads. Just
> the code.

Tests: Does Claude use `std.Thread.Mutex` (0.15) or
`std.Io.Mutex` (0.16)?
