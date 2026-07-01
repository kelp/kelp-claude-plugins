---
description: >
  Tiger Style rules for Zig: assertions (2+ per fn,
  paired positive/negative space), bounded loops (no
  recursion), static memory after init, snake_case
  naming with unit suffixes, 70-line function limit,
  100-column line limit, zig fmt. Use when writing or
  reviewing Zig in a project that follows Tiger Style.
user-invocable: true
---

# Tiger Style -- Quick Reference

This project follows TigerBeetle's Tiger Style. For full
rationale and worked examples, read
`${CLAUDE_PLUGIN_ROOT}/docs/TIGER_STYLE_REFERENCE.md`.

## Safety

**Assertions** -- minimum two per function on average.
Assert arguments, return values, pre/postconditions,
invariants. Pair assertions across code paths. Assert
positive space (what you expect) AND negative space
(what you don't). Split compound asserts:

```zig
// WRONG
assert(a and b);
// RIGHT
assert(a);
assert(b);
```

**Bounded loops, no recursion** -- every loop has an
upper bound; convert recursive algorithms to iterative.
For genuinely non-terminating loops, assert:

```zig
while (true) {
    assert(self.running);
    // ...
}
```

**Static memory** -- allocate everything at init from a
sized arena. After init, the allocator is read-only.

**Errors** -- handle every one. `catch {}` requires a
comment explaining why dropping is safe. Brace
multi-line `if` bodies.

## Naming

- `snake_case` for fn / var / file. PascalCase for types.
- No abbreviations (except `i`, `j`, `k` for sort/matrix
  indices).
- Acronyms keep caps: `VSRState`, not `VsrState`.
- Units as **suffixes, descending significance**:
  `latency_ms_max`, `bytes_per_sector`.
- Helper called by one fn: prefix with caller name:
  `read_sector_callback()`.
- Callbacks go **last** in parameter lists.
- Use `options: struct` when args could be mixed up:

```zig
pub fn open(path: []const u8, options: struct {
    read: bool = true,
    write: bool = false,
}) !File { ... }
```

## Function Shape

- **Hard limit: 70 lines per function.**
- Inverse hourglass: few params, simple return, meaty
  middle.
- **Centralize control flow** -- don't duplicate
  branching in helpers.
- **Push `if`s up, push `for`s down.**

## Variables and Aliasing

- Smallest possible scope.
- Minimize variables in scope.
- Don't take aliases to variables.
- Args > 16 bytes that shouldn't copy: pass `*const T`.
- Group alloc + `defer` with surrounding newlines.

## Comments

- Sentences: space after `//`, capital letter, period.
- Always say **why**, not what.
- For tests, describe goal AND methodology.

## Formatting (Zig)

- `zig fmt`.
- 4-space indent.
- **100 columns hard**, no exceptions.
- Trailing comma + `zig fmt` to wrap signatures.

## Types and Division

- Sized types: `u32`, not `usize` (unless required by
  API).
- Show intent for division: `@divExact`, `@divFloor`,
  `@divTrunc`, or `div_ceil` -- never bare `/` on
  integers.
- Use **explicitly-sized types** like `u32` for
  everything you control.

## Performance Mindset

- Sketch back-of-envelope numbers in design phase.
- Optimize slowest resource first: network > disk >
  memory > CPU.
- Amortize by batching.
- Extract hot loops into standalone fns (no `self`).

## Audit

Run `/tiger-style:tiger-check` to catch mechanical
violations: oversized functions, long lines, `usize`,
recursion, compound asserts, unbounded `while (true)`.
