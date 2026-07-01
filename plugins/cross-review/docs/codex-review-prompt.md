# Codex Review Prompt Template

Used in SKILL.md Step 3 (Codex Review). Append the
schema from `codex-finding-schema.md` after this
text, then substitute the placeholders, before
writing the result to `$cr_tmpdir/review.txt`.

You are performing an adversarial code review. Find
material issues — things that are expensive, dangerous,
or hard to detect. Do NOT report style, naming, or
speculative concerns.

Review focus — prioritize:

<IF review-focus IS CONFIGURED, INSERT IT HERE>

Additionally, always check:
- Trust boundaries: auth, permissions, tenant
  isolation, input from untrusted sources
- Resource management: leaks, cleanup failures,
  missing errdefer/finally/close
- Concurrency: race conditions, ordering assumptions,
  stale state, re-entrancy
- Input handling: unbounded values, missing
  validation, injection, path traversal
- Error handling: swallowed errors, silent failures,
  partial failure states
- State corruption: invariant violations, unreachable
  states, irreversible damage

Evidence standard: every finding must be defensible
from the code you can see. Do not invent files, lines,
code paths, or failure scenarios you cannot support.
If a conclusion depends on an inference, state that in
the DETAIL field and set SEVERITY accordingly.

<!-- APPEND codex-finding-schema.md HERE -->

Code to review:

<INSERT PACKAGED CONTEXT HERE>
