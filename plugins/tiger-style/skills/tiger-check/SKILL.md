---
description: >
  Audit Zig source files for Tiger Style violations --
  functions > 70 lines, lines > 100 columns, usize usage,
  direct recursion, compound assert(a and b), and bare
  while (true) without an adjacent assert.
disable-model-invocation: true
argument-hint: "[file]"
---

# /tiger-check [file]

Audit Zig source files for mechanical Tiger Style
violations. If a file path is given, check that file.
Otherwise check all `*.zig` files that were modified in
the current git diff (staged and unstaged).

Only mechanical rules are covered, checked by reading the
file rather than by a parser -- the function-length and
compound-assertion checks approximate brace and expression
matching, so treat their output as a strong signal, not a
guarantee. Subjective rules (naming quality, prose,
"simplicity") are not. For those, lean on the patterns
in `${CLAUDE_PLUGIN_ROOT}/docs/TIGER_STYLE_REFERENCE.md`.

## Procedure

### 1. Determine target files

If argument provided:
- Check only that file.

If no argument:
- Run `git diff --name-only` and
  `git diff --cached --name-only`.
- Filter to `*.zig` files (include any path, not just
  `src/*.zig`).
- If no modified Zig files, report "No modified Zig
  files to check" and exit.

### 2. Read each target file

Use the Read tool to read the full contents.

### 3. Check for violations

Apply each check below to each file. Report every
violation with file path, line number (or line range
for function-length), and a one-line fix suggestion.

#### Check 1: Function length > 70 lines

For each function definition (`fn name(...)` or
`pub fn name(...)`), find the matching closing `}` for
its opening `{` by reading the file and tracking brace
depth (this is an approximation, not a parse -- watch for
braces inside string literals and comments). If the body
spans more than 70 lines (closing line minus opening line
> 70), flag it.

Report: `WARN: <start>-<end>: function '<name>' is <N>
lines (limit 70)`.

Fix: "Split into helper functions. Push `for`s down
into helpers; keep branching in the parent."

#### Check 2: Line length > 100 columns

For each line whose character length exceeds 100, flag
it.

Caveats:
- Skip lines that are entirely a single string literal
  (e.g. a long URL in a comment or `const`), since
  wrapping would change semantics. Flag with a note
  rather than as a violation.

Report: `WARN: <line>: line is <N> columns (limit 100)`.

Fix: "Wrap with `zig fmt` (add trailing comma to the
preceding signature/call) or extract the long
expression into a named const."

#### Check 3: `usize` usage

Grep each file for the token `usize`. For each
occurrence, flag it.

Caveats:
- `usize` is required when interfacing with stdlib APIs
  that return it (`.len`, allocator sizes, etc.). The
  rule is "avoid where you control the type," not "ban
  outright." Include a note encouraging the user to
  verify whether the use site is constrained by an
  external API.

Report: `WARN: <line>: 'usize' used; prefer explicitly-
sized type (u32, u64) unless required by stdlib API`.

Fix: "Use `u32` or `u64` if you control the type; keep
`usize` only when bound by an external API
signature."

#### Check 4: Direct recursion

For each function definition, scan its body for calls
to the function's own name. Flag any match.

Caveats:
- `inline fn` recursion bounded at comptime is
  sometimes acceptable; flag with a note rather than
  bare violation when the function is `inline fn`.
- Mutual recursion (A calls B, B calls A) is not
  caught by this check; document the limitation in the
  report footer.

Report: `WARN: <line>: function '<name>' recurses
directly; Tiger Style requires iteration with an
explicit stack`.

Fix: "Convert to iteration with a bounded stack
(`std.ArrayListUnmanaged` of frames, sized at init)."

#### Check 5: Compound assertions

Grep for `assert(` calls whose argument contains a
top-level ` and ` or ` or ` (outside nested
parentheses or string literals -- reading the surrounding
code to judge nesting, since this is not a real parse).
Flag each.

Report: `WARN: <line>: compound assertion -- split into
separate asserts for clearer failure messages`.

Fix: "Replace `assert(a and b);` with `assert(a);` and
`assert(b);` on separate lines."

#### Check 6: Bare `while (true)` without adjacent assert

For each `while (true)` (and equivalent like
`while (true) : ()`), read the loop body. If the body
does not contain at least one `assert(` call within
the loop's direct scope, flag it. Direct scope means the
loop's own body, not the body of a function the loop
calls -- an `assert(` inside a helper invoked from the
loop does not satisfy the check.

Report: `WARN: <line>: 'while (true)' without an
assertion in the loop body; non-terminating loops
must assert their invariant`.

Fix: "Add `assert(<invariant>);` near the top of the
loop body to document why the loop is allowed to
never terminate."

### 4. Report results

Format output as:

```
## /tiger-check Results

### <file_path>

WARN: <line>: <description>
  Fix: <suggestion>
WARN: <line>: <description>
  Fix: <suggestion>

### <file_path>

No violations found.

---
Summary: X warnings across Z files
```

If no violations across all files:

```
## /tiger-check Results

All files pass. No Tiger Style violations found.
```

### 5. Caveats footer

Always append:

```
---
Note: /tiger-check covers mechanical rules only. It
does not check naming quality, comment prose, scope
minimization, mutual recursion, or dynamic allocator
usage after init. Review against
`${CLAUDE_PLUGIN_ROOT}/docs/TIGER_STYLE_REFERENCE.md`
for those.
```
