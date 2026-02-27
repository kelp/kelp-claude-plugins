---
description: >
  Audit Zig source files for Zig 0.15.x mistakes -- checks for
  removed APIs (getStdOut, usingnamespace, BoundedArray, async),
  missing flush, wrong ArrayList usage, and ambiguous format strings.
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

2. **takeDelimiterExclusive in while loops:**
   - `while` loop calling `takeDelimiterExclusive` -- use
     `appendRemaining` instead (hangs on stdin)

3. **Missing writer flush:**
   - `stdout_writer` or `stderr_writer` created without a
     corresponding `defer ... flush() catch {}`

4. **ArrayList without allocator:**
   - `.append(`, `.appendSlice(`, `.deinit()` etc. without
     allocator as first argument (for `ArrayListUnmanaged`)

5. **Ambiguous format strings:**
   - `"{}"` in print/format calls -- must use `{s}`, `{d}`,
     `{any}`, etc.

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
