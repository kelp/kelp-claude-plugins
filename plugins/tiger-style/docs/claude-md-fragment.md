## Tiger Style (TigerBeetle Coding Methodology)

This project follows [Tiger Style][upstream]. Apply these
rules when writing or modifying Zig in this repo.

For the long-form reference with rationale and examples,
read `${CLAUDE_PLUGIN_ROOT}/docs/TIGER_STYLE_REFERENCE.md`
or run `/tiger-style:tiger-patterns`.

[upstream]: https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md

### Safety: Assertions

- Assert every function's arguments, return values,
  pre/postconditions, and invariants.
- **Minimum two assertions per function** on average.
- Pair assertions: for every property, assert it in at
  least two different code paths.
- Assert the **positive space** you expect AND the
  **negative space** you don't expect.
- Split compound assertions: prefer `assert(a); assert(b);`
  over `assert(a and b);`.
- Assert relationships of compile-time constants as a
  sanity check.

### Safety: Bounded Loops, No Recursion

- **Do not use recursion.** All bounded executions must be
  bounded by explicit iteration.
- Every loop and every queue must have a fixed upper bound
  to prevent infinite loops or tail latency spikes.
- Where a loop cannot terminate (e.g. an event loop), this
  must be asserted.

### Safety: Static Memory

- **All memory must be statically allocated at startup.**
- No memory may be dynamically allocated (or freed and
  reallocated) after initialization.

### Safety: Error Handling and Control Flow

- **All errors must be handled.** No silent drops.
- Add braces to `if` statements unless the body fits on a
  single line (defense against `goto fail;` bugs).
- Split compound conditions into nested branches; state
  invariants positively.
- Don't react directly to external events; run at your own
  pace. Decouple input from action.
- Ensure functions run to completion without suspending,
  so precondition assertions hold throughout the function.

### Naming

- Use `snake_case` for function, variable, and file names.
- **Do not abbreviate variable names**, with the rare
  exception of primitive integers used as sort/matrix
  arguments.
- Acronyms get proper capitalization: `VSRState`, not
  `VsrState`.
- Add units or qualifiers as **suffixes, sorted by
  descending significance**: `latency_ms_max`, not
  `max_latency_ms`.
- When naming related variables, prefer names with the
  same character count so they line up in source.
- A helper called by a single function should be prefixed
  with the caller's name: `read_sector_callback()`.
- Callbacks go **last** in the parameter list.
- Use Zig's named-argument pattern (`options: struct`)
  when arguments could be mixed up at the call site.

### Function Shape

- **Hard limit: 70 lines per function.** No exceptions.
- Aim for the inverse-hourglass: few parameters, simple
  return type, meaty logic in between.
- **Centralize control flow.** Don't duplicate branching
  in handlers and helpers.
- **Push `if`s up, push `for`s down.** Keep branching in
  one function; move non-branchy work to helpers.

### Variable Scope

- Declare variables at the **smallest possible scope**.
- **Minimize the number of variables in scope** to reduce
  the probability of misuse.
- Calculate or check variables close to where they're
  used. Don't introduce variables before they're needed.
- **Don't duplicate variables or take aliases to them.**
- For arguments larger than 16 bytes that shouldn't be
  copied, pass `*const T`.
- Group resource allocation and its corresponding `defer`
  with surrounding newlines so leaks are easier to spot.

### Comments

- Comments are **sentences**: space after the slash,
  capital letter, full stop (or colon if introducing a
  following block).
- **Always motivate. Always say why.** Code already shows
  what; comments explain why.
- Don't forget to say *how* for non-obvious tests:
  describe goal and methodology.

### Formatting (Zig-Specific)

- Run `zig fmt`.
- **4 spaces of indentation** (not 2).
- **Hard limit all line lengths to 100 columns**, no
  exceptions. Never hide code behind horizontal scroll.
- To wrap a function signature or struct, add a trailing
  comma and let `zig fmt` do the rest.

### Types, Division, and Library Calls

- Use **explicitly-sized types** like `u32`. Avoid
  architecture-dependent `usize` unless interfacing with
  APIs that require it.
- Show intent for division: use `@divExact`, `@divFloor`,
  or `div_ceil` rather than bare `/`. (See `/zig-check`
  for `@divTrunc`/`@divFloor` enforcement.)
- **Pass options explicitly** at the call site rather
  than relying on defaults.

### Performance Mindset

- The huge (1000x) performance wins come at the **design
  phase**, before you can measure. Sketch back-of-envelope
  numbers for the four resources (network, disk, memory,
  CPU) and their two characteristics (bandwidth, latency).
- **Optimize the slowest resource first**: network, then
  disk, then memory, then CPU.
- **Amortize** costs by batching accesses.
- Extract hot loops into standalone functions with
  primitive arguments (no `self`) to enable compiler
  optimization and human inspection.

### When Auditing

Run `/tiger-style:tiger-check` to scan changed Zig files
for mechanical Tiger Style violations: oversized
functions, long lines, `usize` usage, direct recursion,
compound asserts, and unbounded `while (true)`.
