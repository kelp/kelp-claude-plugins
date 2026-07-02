---
description: >
  Audit Zig source files for outdated APIs against the project's
  Zig version (0.15.x or 0.16.x). Detects removed APIs, missing
  io parameters, missing flush, wrong ArrayList usage, ambiguous
  format strings, signed division, and renamed stdlib functions.
disable-model-invocation: true
argument-hint: "[file]"
---

# /zig-check [file]

Audit Zig source files for outdated APIs. The plugin supports
both Zig 0.15.x and 0.16.x; this skill detects the target
version and applies the matching rule set. If a file path is
given, check that file. Otherwise check all `*.zig` files, in
any directory, that were modified in the current git diff
(staged and unstaged).

## Procedure

### 1. Detect Zig version

Run:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/detect-zig-version.sh
```

Capture the output as `$VERSION` (`0.15` or `0.16`).

### 2. Determine target files

If argument provided:
- Check only that file

If no argument:
- Run `git diff --name-only` and `git diff --cached --name-only`
- Filter to `*.zig` files, recursively, regardless of directory
- If no modified Zig files, report "No modified Zig files to
  check" and exit

### 3. Read each target file

Use the Read tool to read the full contents of each file.

### 4. Apply the version-specific rule set

Search each file for the patterns below. Report each violation
with file path, line number, and the specific issue.

### Rules that apply to BOTH 0.15.x and 0.16.x

These are wrong on every supported Zig version:

1. **Deleted-in-0.15 APIs:**
   - `std.io.getStdOut` / `std.io.getStdErr` -- use buffered
     writer pattern
   - `usingnamespace` -- removed from language
   - `async` / `await` -- removed from language
   - `std.BoundedArray` -- use `ArrayListUnmanaged.initBuffer`
   - `std.json.Parser` -- use `std.json.parseFromSlice`

2. **Renamed APIs (still valid in both versions):**
   - `std.mem.tokenize(` without `Any`/`Scalar`/`Sequence` --
     use `tokenizeAny`, `tokenizeScalar`, or `tokenizeSequence`

3. **ArrayList without allocator:**
   - `.append(`, `.appendSlice(`, `.deinit()` etc. without
     allocator as first argument (for `ArrayListUnmanaged`)

4. **Ambiguous format strings:**
   - `"{}"` in print/format calls -- must use `{s}`, `{d}`,
     `{any}`, etc.

5. **Signed division without builtins:**
   - `/` or `%` on runtime signed integer variables -- use
     `@divTrunc`, `@divFloor`, `@divExact`, `@rem`, `@mod`

6. **Old for-loop index syntax:**
   - `for (items) |item, i|` without explicit index range --
     use `for (items, 0..) |item, i|`

### Additional rules for 0.15.x ONLY (`$VERSION == 0.15`)

7. **`std.process.args()` without `Alloc`:**
   - Use `std.process.argsAlloc(allocator)`

8. **`takeDelimiterExclusive` in while loops:**
   - `while` loop calling `takeDelimiterExclusive` -- use
     `appendRemaining` instead (hangs on stdin)

9. **Missing writer flush:**
   - `stdout_writer` or `stderr_writer` created without a
     corresponding `defer ... flush() catch {}`

### Additional rules for 0.16.x ONLY (`$VERSION == 0.16`)

7. **`std.fs` namespace usage (moved to `std.Io`):**
   - `std.fs.File` -- use `std.Io.File`
   - `std.fs.Dir` -- use `std.Io.Dir`
   - `std.fs.cwd()` -- use `std.Io.Dir.cwd()`
   - `std.fs.path` -- use `std.Io.Dir.path`

8. **`std.mem.indexOf*` (renamed to `find*`):**
   - `std.mem.indexOf(` -- use `std.mem.find(`
   - `std.mem.indexOfScalar(` -- use `std.mem.findScalar(`
   - `std.mem.indexOfPos(` -- use `std.mem.findPos(`
   - `std.mem.indexOfAny(` -- use `std.mem.findAny(`
   - `std.mem.lastIndexOf*` -- use `std.mem.findLast*`

9. **Global process state (no longer global):**
   - `std.os.environ` -- removed; route `init.environ_map`
     from `std.process.Init`
   - `std.process.getCwd` / `getCwdAlloc` -- use
     `std.process.currentPath` / `currentPathAlloc` (with `io`)

10. **`std.process.Child` API (rewritten):**
    - `std.process.Child.init(` -- use
      `std.process.spawn(io, .{ .argv, ... })`
    - `Child.run(` -- use `std.process.run(allocator, io, .{...})`

11. **Sync primitives moved (`std.Thread.*` -> `std.Io.*`):**
    - `std.Thread.Mutex` / `Condition` / `ResetEvent` /
      `WaitGroup` / `RwLock` / `Semaphore` / `Futex` -- use
      `std.Io.Mutex` / `Condition` / `Event` / `Group` /
      `RwLock` / `Semaphore` / `Futex`
    - `std.Thread.Pool` -- removed; use `std.Io.async`

12. **Removed allocators / containers:**
    - `std.heap.ThreadSafeAllocator` -- removed
      (`ArenaAllocator` is now lock-free thread-safe)
    - `std.ArrayHashMap` / `AutoArrayHashMap` /
      `StringArrayHashMap` (managed) -- use
      `array_hash_map.Custom` / `Auto` / `String`
    - `std.SegmentedList` -- removed

13. **Removed I/O types:**
    - `std.io.fixedBufferStream` -- use
      `var w: std.Io.Writer = .fixed(buf);` /
      `var r: std.Io.Reader = .fixed(data);`
    - `std.io.GenericReader` / `AnyReader` -- use
      `std.Io.Reader`
    - `std.io.GenericWriter` / `AnyWriter` -- removed

14. **`@Type(.{ ... })` reflection (split into 8 builtins):**
    - `@Type(.{ .int =` -- use `@Int(.unsigned, N)` /
      `@Int(.signed, N)`
    - `@Type(.{ .struct =` -- use `@Struct(...)`
    - `@Type(.{ .union =` -- use `@Union(...)`
    - `@Type(.{ .enum =` -- use `@Enum(...)`
    - `@Type(.{ .enum_literal` -- use `@EnumLiteral()`
    - `@Type(.{ .pointer =` -- use `@Pointer(...)`
    - `@Type(.{ .fn =` -- use `@Fn(...)`
    - `@Type(.{ .tuple =` -- use `@Tuple(...)`

15. **`@cImport` deprecated:**
    - `@cImport(` -- use `b.addTranslateC(...)` in build.zig

16. **`std.fs.File.stdout/stderr/stdin` (moved namespace):**
    - `std.fs.File.stdout(` -- use `std.Io.File.stdout(`
    - `std.fs.File.stderr(` -- use `std.Io.File.stderr(`
    - `std.fs.File.stdin(` -- use `std.Io.File.stdin(`

17. **0.15-era buffered stdout pattern:**
    - `std.fs.File.stdout().writerStreaming(&` -- use
      `std.Io.File.stdout().writerStreaming(io, &buf)` (the
      `writerStreaming` constructor still exists in 0.16 and
      is still required for stdout/stderr to respect O_APPEND
      — `writer(io, &buf)` is the positional variant and
      silently ignores O_APPEND, breaking shell `>>` redirects)

### 5. Report results

Format output as:

```
## /zig-check Results (Zig $VERSION.x rules)

### <file_path>

CRITICAL: <line>: <description>
CRITICAL: <line>: <description>

### <file_path>

No issues found.

---
Summary: X critical across Z files
```

If no issues found in any file:

```
## /zig-check Results (Zig $VERSION.x rules)

All files pass. No issues found.
```

### 6. Suggest fixes

For each critical issue, include a one-line fix suggestion.
Examples:

- "Replace `std.io.getStdOut()` with buffered writer pattern
  (see /zig-claude-kit:zig-patterns)"
- "Replace `while (reader.takeDelimiterExclusive(...))` with
  `reader.appendRemaining()`"
- "Add `defer stdout.flush() catch {};` after writer creation"
- "Add `io` parameter: `file.close()` -> `file.close(io)`"
- "Move namespace: `std.fs.File` -> `std.Io.File`"
- "Rename: `std.mem.indexOf` -> `std.mem.find`"
- "Replace `std.fs.cwd()` with `std.Io.Dir.cwd()`"
- "Replace global env access with `init.environ_map`"
- "Replace `std.Thread.Mutex` with `std.Io.Mutex`"
- "Replace `@Type(.{ .int = ... })` with `@Int(.unsigned, N)`"
- "Replace `std.io.fixedBufferStream(buf).writer()` with
  `var w: std.Io.Writer = .fixed(buf);`"
- "Change `list.append(val)` to `list.append(allocator, val)`"
- "Change `\"{}\"` to `\"{s}\"` (or appropriate specifier)"
- "Replace `a / b` with `@divTrunc(a, b)` for signed integers"
- "Replace `std.mem.tokenize` with `std.mem.tokenizeAny`"
- "Change `for (items) |x, i|` to `for (items, 0..) |x, i|`"
- "Replace `std.json.Parser` with `std.json.parseFromSlice`"
