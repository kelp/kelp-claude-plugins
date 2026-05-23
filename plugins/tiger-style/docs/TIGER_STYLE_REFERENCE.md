# Tiger Style Reference

Long-form companion to the [CLAUDE.md fragment][frag].
Quotes and paraphrases the upstream [TIGER_STYLE.md][up]
maintained by TigerBeetle (Apache-2.0). When the fragment
gives you a rule, this doc gives you the rationale and
worked examples.

[frag]: ./claude-md-fragment.md
[up]: https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md

## Philosophy

Tiger Style sits on three pillars: **safety**,
**performance**, **developer experience**. Each rule
serves at least one pillar, usually all three.

### Why have style?

Style is the set of decisions made once so they don't
have to be made over and over. A consistent style means
readers spend their attention on what's novel about the
code, not what's arbitrary.

### Simplicity and elegance

> Simplicity is also not the first attempt but the
> hardest revision.

Simple, elegant systems are easier to design, faster to
execute, and far more reliable than clever ones. Aim for
boring code that does what it says.

### Zero technical debt

> A problem solved in production is many times more
> expensive than a problem solved in implementation, or
> a problem solved in design.

Discover and resolve showstoppers in design and
implementation, not production. Refuse to ship anything
you'd be embarrassed to maintain in a year.

## Safety

### Assertions

The single highest-leverage practice in Tiger Style.

> The assertion density of the code must average a
> minimum of two assertions per function.

Why:
- Assertions catch wrong assumptions where they're made,
  not at some distant downstream point where the cause
  is obscured.
- They downgrade catastrophic bugs (silent corruption)
  into liveness bugs (loud crash).
- They are a force multiplier for fuzzing: an
  unasserted bug only fires when its output is observed;
  an asserted bug fires the first time the invariant
  breaks.

Rules:
- Assert all function arguments and return values.
- Assert pre-conditions, post-conditions, invariants.
- **Pair assertions**: for every property you enforce,
  find at least two different code paths where you can
  assert it. If you can't find a second path, the
  property is probably too local to matter.
- Assert the **positive space** you expect AND the
  **negative space** you don't expect.
- **Split compound assertions.** `assert(a); assert(b);`
  tells you which clause failed; `assert(a and b);`
  doesn't.
- Assert relationships between compile-time constants as
  a sanity check (e.g. `comptime assert(SECTOR_SIZE %
  PAGE_SIZE == 0);`).

Example (positive + negative space):

```zig
fn parse_header(buf: []const u8) !Header {
    assert(buf.len >= MIN_HEADER_SIZE); // positive
    assert(buf.len <= MAX_HEADER_SIZE); // negative
    // ...
}
```

### Bounded loops, no recursion

> Do not use recursion to ensure that all executions
> that should be bounded are bounded.

> All loops and all queues must have a fixed upper
> bound to prevent infinite loops or tail latency
> spikes.

Why: unbounded iteration is unbounded latency.
Recursion is unbounded stack. Both turn into denial of
service the first time a malicious or malformed input
arrives.

Rules:
- Every loop has a compile-time or runtime upper bound.
- Where a loop genuinely cannot terminate (event loops,
  schedulers), assert that fact:
  ```zig
  while (true) {
      assert(self.running);
      // ...
  }
  ```
- Convert recursive algorithms to iterative with an
  explicit stack.

### Static memory

> All memory must be statically allocated at startup.
> No memory may be dynamically allocated (or freed and
> reallocated) after initialization.

Why:
- Eliminates use-after-free and double-free.
- Eliminates fragmentation and OOM in steady state.
- Makes worst-case memory predictable from the binary
  alone.
- Forces you to think about capacity at design time.

Pattern:
- During init, allocate all pools, queues, buffers from
  a single arena sized for the worst case.
- After init, the allocator is read-only: passing it
  around is a code smell.

### Error handling

> 92% of catastrophic failures stem from incorrect
> error handling.

- **All errors must be handled.** No `catch {}` without
  a comment explaining why dropping the error is safe.
- Use `try` to propagate; use `catch |err|` to handle;
  never silently discard.
- Brace multi-line `if` bodies. Single-line bodies may
  omit braces, but the moment you add a second
  statement, add braces. This is the `goto fail;`
  lesson.

### Control flow

- Don't react to external events directly. Run at your
  own pace, drain queues, batch work.
- Ensure functions run to completion without
  suspending, so precondition assertions hold for the
  entire function body.
- Split compound conditions into nested branches when
  the components are independently meaningful.
- State invariants positively: `if (valid)` reads
  better than `if (!invalid)`.

### Variable scope and aliasing

- Declare at the smallest possible scope. A variable
  declared at the top of a 50-line function is in scope
  for 50 lines of misuse.
- **Minimize the number of variables in scope.**
- Don't take aliases to variables. `const x = self.foo;`
  followed by mutations to `self.foo` is a bug waiting
  to happen.
- For arguments larger than 16 bytes that shouldn't be
  copied, pass `*const T`. The 16-byte threshold is two
  pointers; anything bigger benefits from
  pass-by-reference.
- Construct large structs in-place by passing an
  **out-pointer** during initialization.
- Watch for **buffer bleeds** (buffer underflow — the
  opposite of overflow): reading or writing before the
  start of a buffer due to off-by-one slicing.
- Group resource allocation and its corresponding
  `defer` with surrounding newlines:

  ```zig
  // good: alloc + defer visually grouped

  const buf = try allocator.alloc(u8, size);
  defer allocator.free(buf);

  // do work
  ```

## Developer Experience

### Naming

> Get the nouns and verbs just right.

Rules:
- `snake_case` for functions, variables, and file
  names. (Types are an exception — `PascalCase` is
  idiomatic Zig.)
- **Do not abbreviate.** Exceptions: primitive integers
  used as a sort/matrix argument (`i`, `j`, `k`).
- Acronyms get proper capitalization in types:
  `VSRState`, not `VsrState`.
- Units and qualifiers go as **suffixes, sorted by
  descending significance**:
  - `latency_ms_max` (latency, milliseconds, max)
  - `bytes_per_sector` (bytes, per sector)
  - This makes related variables sort and align.
- When naming related variables, prefer names with the
  same character count so they line up:
  ```zig
  const sector_first: u32 = 0;
  const sector_count: u32 = 8;
  ```
- A helper called by a single function gets the
  caller's name as prefix: `read_sector_callback()`.
- Callbacks go **last** in parameter lists.
- Use Zig's `options: struct` pattern when arguments
  could be mixed up at the call site:
  ```zig
  pub fn open(path: []const u8, options: struct {
      read: bool = true,
      write: bool = false,
      create: bool = false,
  }) !File { ... }
  ```
- Avoid context-dependent meanings. A name that means
  different things in different functions is a name
  that has no meaning.
- Think of how names read in commit messages, code
  review, and prose. Names that are awkward to say are
  usually awkward in code too.

### Function shape

- **Hard limit: 70 lines per function.** A function
  that scrolls is a function you can't see whole.
- The ideal function shape is an inverse hourglass: few
  parameters in, simple type out, meaty logic between
  the braces.
- **Centralize control flow.** If two helpers both
  branch on the same condition, the branch belongs in
  the caller.
- **Push `if`s up, push `for`s down.** Keep branching
  in one place; move straight-line work into helpers.

### Comments

- Comments are **prose**, not scribblings.
- Space after the slash, capital letter, period at the
  end (or colon if introducing a following block).
- **Always say why.** "Increment counter" is not a
  comment. "Counter wraps on overflow because callers
  treat 0 as 'not yet seen'" is.
- For tests, describe the goal and the methodology, not
  just the assertion.
- Write descriptive commit messages. The PR description
  isn't kept in git history; the commit message is.

### Style by the numbers (Zig)

- `zig fmt` is the source of truth for formatting.
- **4 spaces** of indentation, not 2.
- **100 columns**, hard limit, no exceptions. Code
  hidden behind horizontal scroll is code you don't
  read.
- To wrap a function signature, call, or struct
  literal: add a trailing comma and let `zig fmt` do
  the rest.

## Performance

### Design-time thinking

> The best time to solve performance, to get the huge
> 1000x wins, is in the design phase, which is
> precisely when we can't measure or profile.

Sketch back-of-the-envelope numbers across four
resources and two characteristics:

| Resource | Bandwidth | Latency |
|----------|-----------|---------|
| Network  | ~Gbps     | ~ms     |
| Disk     | ~GB/s     | ~ms     |
| Memory   | ~10s GB/s | ~100ns  |
| CPU      | ~10s GHz  | ~ns     |

**Optimize the slowest resource first.** Network beats
disk beats memory beats CPU. A CPU-optimal algorithm
that triples your disk reads is a regression.

### Batching and mechanical sympathy

> Let the CPU be a sprinter doing the 100m. Be
> predictable.

- Amortize fixed costs by batching.
- Avoid context switching mid-operation.
- Predictable branches; predictable memory access.
- Extract hot loops into standalone functions with
  primitive arguments (no `self`). This lets the
  compiler optimize aggressively and lets humans
  inspect the hot path in isolation.

### Off-by-one errors

> The usual suspects for off-by-one errors are casual
> interactions between an `index`, a `count`, or a
> `size`.

- Indexes are 0-based; counts are 1-based; sizes are in
  bytes. Mixing them quietly is a bug.
- Put units in variable names so the mix-up is visible:
  `index_first`, `count_total`, `size_bytes`.
- For division, **show your intent**:
  - `@divExact(a, b)` — assert the division is exact.
  - `@divFloor(a, b)` — round toward negative infinity.
  - `@divTrunc(a, b)` — round toward zero (default `/`
    on integers, but be explicit).
  - `div_ceil(a, b)` — round up (your own helper).

## Dependencies and Tooling

### Zero dependencies

> TigerBeetle has a "zero dependencies" policy, apart
> from the Zig toolchain.

Note: this is aspirational for most projects. The
underlying point is real: every dependency is a supply
chain risk, a build-time tax, and a potential safety
or performance gap. Add dependencies deliberately.

### Tooling in the project language

> The next time you write a script, instead of
> `scripts/*.sh`, write `scripts/*.zig`.

Why: standardizing on one language for tooling reduces
the number of build systems, package managers, and
environment configurations contributors need to know.

### Compiler warnings

> Appreciate, from day one, all compiler warnings at
> the compiler's strictest setting.

Be explicit. Minimize dependence on the compiler doing
the right thing for you implicitly.

## Quick Reference: What `/tiger-check` Catches

The audit skill is mechanical — it can't judge naming
or simplicity. It does catch:

- Functions longer than 70 lines
- Lines longer than 100 columns
- `usize` usage (suggest `u32` or `u64`)
- Direct recursion (function calling itself)
- `assert(a and b)` compound asserts
- Bare `while (true)` without an adjacent assert

Run it on changed files before review:

```
/tiger-style:tiger-check
```

## Attribution

This document paraphrases and quotes from TigerBeetle's
[TIGER_STYLE.md][up], which is Apache-2.0 licensed.
TigerBeetle developed Tiger Style for their financial
database. Adapt as needed for your context — the
philosophy travels well; some rules (zero dependencies,
write tooling in your project language) are easier to
follow in a focused codebase than in a sprawling one.
