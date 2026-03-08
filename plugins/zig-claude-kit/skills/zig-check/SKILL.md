---
description: >
  Audit Zig source files for Zig 0.15.x mistakes -- checks for
  removed APIs (getStdOut, usingnamespace, BoundedArray, async),
  missing flush, wrong ArrayList usage, ambiguous format strings,
  signed division, and renamed stdlib functions.
disable-model-invocation: true
argument-hint: "[file]"
---

# /zig-check [file]

Audit Zig source files for common Zig 0.15.x mistakes. If a file
path is given, check that file. Otherwise check all `src/*.zig`
files that were modified in the current git diff (staged and
unstaged).

## Procedure

### 1. Determine target files

If argument provided:
- Check only that file

If no argument:
- Run `git diff --name-only` and `git diff --cached --name-only`
- Filter to `src/*.zig` files
- If no modified Zig files, report "No modified Zig files to
  check" and exit

### 2. Read each target file

Use the Read tool to read the full contents of each file.

### 3. Check for violations

Search each file for these patterns. Report each violation with
file path, line number, and the specific issue.

#### Critical (must fix):

1. **Deleted API usage:**
   - `std.io.getStdOut` or `std.io.getStdErr` -- use buffered
     writer pattern
   - `usingnamespace` -- removed from language
   - `async` / `await` -- removed from language
   - `std.BoundedArray` -- use `ArrayListUnmanaged.initBuffer`
   - `std.json.Parser` -- use `std.json.parseFromSlice`

2. **Renamed API usage:**
   - `std.mem.tokenize(` without `Any`/`Scalar`/`Sequence` --
     use `tokenizeAny`, `tokenizeScalar`, or
     `tokenizeSequence`
   - `std.process.args()` without `Alloc` -- use
     `std.process.argsAlloc(allocator)`

3. **takeDelimiterExclusive in while loops:**
   - `while` loop calling `takeDelimiterExclusive` -- use
     `appendRemaining` instead (hangs on stdin)

4. **Missing writer flush:**
   - `stdout_writer` or `stderr_writer` created without a
     corresponding `defer ... flush() catch {}`

5. **ArrayList without allocator:**
   - `.append(`, `.appendSlice(`, `.deinit()` etc. without
     allocator as first argument (for `ArrayListUnmanaged`)

6. **Ambiguous format strings:**
   - `"{}"` in print/format calls -- must use `{s}`, `{d}`,
     `{any}`, etc.

7. **Signed division without builtins:**
   - `/` or `%` on runtime signed integer variables -- use
     `@divTrunc`, `@divFloor`, `@divExact`, `@rem`, `@mod`

8. **Old for-loop index syntax:**
   - `for (items) |item, i|` without explicit index range --
     use `for (items, 0..) |item, i|`

### 4. Report results

Format output as:

```
## /zig-check Results

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
## /zig-check Results

All files pass. No Zig 0.15.x issues found.
```

### 5. Suggest fixes

For each critical issue, include a one-line fix suggestion:

- "Replace `std.io.getStdOut()` with buffered writer pattern
  (see zig-patterns skill)"
- "Replace `while (reader.takeDelimiterExclusive(...))` with
  `reader.appendRemaining()`"
- "Add `defer stdout.flush() catch {};` after writer creation"
- "Change `list.append(val)` to `list.append(allocator, val)`"
- "Change `"{}"` to `"{s}"` (or appropriate specifier)"
- "Replace `a / b` with `@divTrunc(a, b)` for signed integers"
- "Replace `std.mem.tokenize` with `std.mem.tokenizeAny`"
- "Replace `std.process.args()` with `std.process.argsAlloc`"
- "Change `for (items) |x, i|` to `for (items, 0..) |x, i|`"
- "Replace `std.json.Parser` with `std.json.parseFromSlice`"
