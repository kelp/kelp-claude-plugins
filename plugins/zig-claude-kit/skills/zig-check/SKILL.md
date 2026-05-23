---
description: >
  Audit Zig source files for outdated patterns. Auto-detects whether
  the project targets 0.15.x or 0.16 and applies the matching ruleset:
  removed APIs (getStdOut, usingnamespace, BoundedArray, async),
  wrong I/O / fs / process / Thread patterns, missing flush,
  ArrayList usage, ambiguous format strings, signed division, and
  renamed stdlib functions.
disable-model-invocation: true
argument-hint: "[file]"
---

# /zig-check [file]

Audit Zig source files for outdated APIs. If a file path is given,
check that file. Otherwise check all `src/*.zig` files that were
modified in the current git diff (staged and unstaged).

## Procedure

### 1. Detect the project's Zig version

Run `${CLAUDE_PLUGIN_ROOT}/scripts/detect-zig-version.sh` from the
project root. It prints `0.15` or `0.16`. Apply the matching rules
below.

### 2. Determine target files

If argument provided:
- Check only that file

If no argument:
- Run `git diff --name-only` and `git diff --cached --name-only`
- Filter to `src/*.zig` files
- If no modified Zig files, report "No modified Zig files to check"
  and exit

### 3. Read each target file

Use the Read tool to read the full contents of each file.

### 4. Check for violations

Search each file for patterns. Report each with file path, line
number, and the specific issue.

---

## Rules That Apply to Both Versions

These corrections apply regardless of detected version.

1. **Removed language features:**
   - `usingnamespace` -- removed from language
   - `async` / `await` keywords -- removed from language
   - `std.BoundedArray` -- use `ArrayListUnmanaged.initBuffer`
   - `std.json.Parser` -- use `std.json.parseFromSlice`

2. **Renamed stdlib functions:**
   - `std.mem.tokenize(` without `Any`/`Scalar`/`Sequence` -- use
     `tokenizeAny`, `tokenizeScalar`, or `tokenizeSequence`

3. **Ambiguous format strings:**
   - `"{}"` in print/format calls -- must use `{s}`, `{d}`, `{any}`,
     etc. Use `{f}` to call custom format methods.

4. **Signed division without builtins:**
   - `/` or `%` on runtime signed integer variables -- use
     `@divTrunc`, `@divFloor`, `@divExact`, `@rem`, `@mod`

5. **Old for-loop index syntax:**
   - `for (items) |item, i|` without explicit index range -- use
     `for (items, 0..) |item, i|`

6. **ArrayList without allocator:**
   - `.append(`, `.appendSlice(`, `.deinit()` without allocator
     as first argument (for ArrayListUnmanaged / 0.16 ArrayList)

7. **Old format method signature:**
   - `pub fn format(self: T, comptime fmt: ...)` -- new signature
     is `pub fn format(self: T, writer: *std.Io.Writer) ...`

---

## Rules When Project Targets 0.15.x

8. **Deleted APIs (0.15):**
   - `std.io.getStdOut` / `std.io.getStdErr` -- use buffered writer
     pattern via `std.fs.File.stdout()`

9. **takeDelimiterExclusive in while loops:**
   - `while` loop calling `takeDelimiterExclusive` -- use
     `appendRemaining` instead (hangs on stdin)

10. **Missing writer flush:**
    - `stdout_writer` / `stderr_writer` created without a
      corresponding `defer ... flush() catch {}`

11. **Old process args:**
    - `std.process.args()` returning iterator (without `Alloc`) --
      use `std.process.argsAlloc(allocator)`

---

## Rules When Project Targets 0.16

8. **Deleted / moved APIs (0.16 on top of 0.15):**
   - `std.io.getStdOut` / `std.io.getStdErr` -- doubly wrong; use
     `std.Io.File.stdout()` and `writerStreaming(io, &buf)`
   - `std.fs.File.stdout()` -- moved to `std.Io.File.stdout()`
   - `std.fs.File` / `std.fs.Dir` -- moved to `std.Io.File` /
     `std.Io.Dir`
   - `std.fs.cwd()` -- moved to `std.Io.Dir.cwd()`
   - `std.os.environ` -- gone; use `init.environ_map`
   - `std.process.argsAlloc` / `argsFree` -- gone; use
     `init.minimal.args.toSlice(allocator)`
   - `std.process.getCwd` / `getCwdAlloc` -- renamed to
     `currentPath` / `currentPathAlloc` (and take `io`)
   - `std.process.Child.init(...).spawn()` -- use
     `std.process.spawn(io, .{...})`
   - `std.posix.PROT.READ | std.posix.PROT.WRITE` -- use
     `.{ .READ = true, .WRITE = true }`
   - `std.posix.mlock` family -- moved to `std.process.lockMemory`
   - `std.Thread.Mutex` / `Condition` / `Semaphore` / `WaitGroup`
     / `ResetEvent` / `Futex` / `RwLock` -- moved to `std.Io.*`
   - `std.Thread.Pool` -- gone; use `std.Io.async` /
     `std.Io.Group.async`
   - `std.crypto.random.bytes` -- use `io.random(&buf)`
   - `std.time.Instant` / `Timer` / `timestamp` -- collapsed into
     `std.Io.Timestamp`
   - `@Type(.{ .int = ... })` -- use `@Int(.unsigned, N)` (and the
     seven other builtins: `@EnumLiteral`, `@Tuple`, `@Pointer`,
     `@Fn`, `@Struct`, `@Union`, `@Enum`)
   - `@cImport({ @cInclude(...) })` -- deprecated; use
     `b.addTranslateC(...)` in `build.zig`

9. **Renamed stdlib functions (0.16):**
   - `std.mem.indexOf` -- use `std.mem.find`
   - `std.mem.indexOfScalar` -- use `std.mem.findScalar`
   - `std.mem.indexOfPos` -- use `std.mem.findPos`
   - `std.mem.indexOfAny` -- use `std.mem.findAny`
   - `std.mem.lastIndexOf` -- use `std.mem.findLast`
   - `std.mem.lastIndexOfScalar` -- use `std.mem.findScalarLast`
     (note: `Last` comes after `Scalar`)
   - `Dir.makeDir(name)` -- use `Dir.createDir(io, name)`
   - `Dir.makePath(path)` -- use `Dir.createDirPath(io, path)`
   - `File.chmod` / `Dir.chmod` -- use `setPermissions(io, ...)`
   - `File.setEndPos` / `getEndPos` -- use `setLength(io)` /
     `length(io)`
   - `File.write` / `writeAll` / `read` -- use `writeStreaming(io)` /
     `writeStreamingAll(io)` / `readStreaming(io)`

10. **Missing `io` parameter:**
    - `file.close()` -- now requires `file.close(io)`
    - Other file/dir methods missing `io` as first arg

11. **`main` signature missing init:**
    - `pub fn main() !void` where the function reads args/env --
      should be `pub fn main(init: std.process.Init) !void`
    - Reading `std.os.environ` or calling `std.process.argsAlloc`
      inside such a `main` is doubly wrong

12. **Error name renames (0.16):**
    - `error.RenameAcrossMountPoints` / `NotSameFileSystem` --
      use `error.CrossDevice`
    - `error.SharingViolation` -- use `error.FileBusy`
    - `error.FileTooBig` from `readFileAlloc` -- use
      `error.StreamTooLong`

13. **Managed hash maps:**
    - `std.AutoArrayHashMap(K, V).init(allocator)` -- use
      `std.array_hash_map.Auto(K, V) = .empty`
    - Same for `StringArrayHashMap` -> `array_hash_map.String`
    - Same for `ArrayHashMap` -> `array_hash_map.Custom`

### 5. Report results

Format output as:

```
## /zig-check Results (Zig X.Y target)

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
## /zig-check Results (Zig X.Y target)

All files pass. No issues found.
```

Always include the detected target version in the header so the
user can confirm the right ruleset was applied.

### 6. Suggest fixes

For each critical issue, include a one-line fix suggestion citing
the right replacement API. Reference the version-specific breaking
changes doc when relevant:

- 0.15: `${CLAUDE_PLUGIN_ROOT}/docs/ZIG_BREAKING_CHANGES-0.15.md`
- 0.16: `${CLAUDE_PLUGIN_ROOT}/docs/ZIG_BREAKING_CHANGES-0.16.md`
