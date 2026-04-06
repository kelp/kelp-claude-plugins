---
name: cross-review
description: >
  Multi-model code review with cross-validation.
  Orchestrates independent Claude and GPT-5.4 reviews,
  cross-validates findings, outputs merged fix list.
  Use when reviewing code changes, auditing files, or
  wanting a second opinion. Triggers on: "cross-review",
  "multi-model review", "review with codex", "get a
  second opinion on this code".
user-invocable: true
---

# /cross-review

Independent reviews from two models, cross-validated,
merged into a single prioritized fix list.

## Input

Scope: $ARGUMENTS

Default (no arguments): all uncommitted changes,
equivalent to `git diff HEAD`.

Accepted scope forms:
- File path: `src/server.zig`
- Git range: `last 2 commits`, `HEAD~3..HEAD`
- Any freeform description — translate it to the
  appropriate git diff or file list.

Flags:
- `--quick`: skip cross-validation; merge findings
  from both models without checking each other's work.
- `--reconcile`: after cross-validation, ask each
  model to reconsider its disputed findings in light
  of the validator's reasoning. Incompatible with
  `--quick`. Adds one round of reconciliation per
  disputed finding.

## The Rule

**You are a PURE DISPATCHER. You NEVER edit source files.**

Violations you MUST NOT commit:
- Writing or editing any source, test, or config file
- Fixing issues you find during review
- Modifying code "just to note the fix inline"
- Combining dispatch and implementation in one step
- Skipping any pipeline stage

What you DO:
- Read files and diffs to package context
- Dispatch reviewer and validator agents
- Shell out to codex for GPT-5.4 reviews
- Parse and normalize findings
- Merge results and format output

If you catch yourself about to use Write or Edit on
a source file, STOP. You are the reviewer, not the
fixer. Format the finding and move on.

## Red Flags — You Are Skipping the Pipeline

- "I'll just fix this one while I'm here"
- "This finding is obvious, no need to cross-validate"
- "Let me inline the fix in the review output"
- "Codex is unavailable, I'll skip the merge step"
- "The findings are similar enough, I'll deduplicate
  manually without normalizing"

All of these mean STOP. Follow the pipeline.

---

## Pipeline

### Step 1: Determine Scope and Package Context

Parse `$ARGUMENTS`:
- Strip `--quick` flag if present; record it.
- Remaining text is the scope. If empty, use
  `git diff HEAD`.
- Translate freeform scope to git commands or file
  paths as needed.

Read the project's root CLAUDE.md for configuration.
Look for lines starting with these keys — the value
is everything after the colon, trimmed:

- `codex-script:` — path to the codex companion
  script. Expand `$HOME` to the user's home directory
  before use. If missing or unreadable, proceed in
  claude-only mode (see Output Formats).
- `review-focus:` — optional project-specific review
  priorities. If present, prepend these to the review
  focus in both Claude and Codex prompts.

Package context: read the relevant files and diffs
once. Inline the code slices in every prompt you
send to reviewers and validators. Agents may still
read additional files if the provided context is
insufficient — the goal is to avoid redundant reads,
not to restrict investigation.

### Step 2: Claude Review

Read the reviewer role skill verbatim:
`${CLAUDE_PLUGIN_ROOT}/skills/reviewer/SKILL.md`

Dispatch a **reviewer** agent (`subagent_type:
reviewer`) with:
- The reviewer skill content (verbatim)
- The packaged code context (files and diffs)
- Project-specific review-focus from CLAUDE.md
  (if configured)
- Instruction to return findings in the finding schema

Collect the agent's output. If the agent returns
`NO_FINDINGS`, record an empty finding list for
Claude.

### Step 3: Codex Review

If no codex script path was found in Step 1, skip
this step and proceed in claude-only mode.

Shell out to the codex companion script:

```bash
node <codex-script-path> task --wait "<prompt>"
```

The prompt must include:
1. The packaged code context (same as Step 2)
2. The full finding schema (codex cannot read the
   reviewer skill file directly)
3. The review focus categories
4. Instruction to return findings using that schema

Use this prompt template:

---
**Codex Review Prompt Template**

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

Return findings in this exact schema. Each finding
must fill every field.

    FINDING: <sequential id starting at 1>
    FILE: <path relative to repo root>
    LINES: <start>-<end>
    SEVERITY: <high|medium|low>
    CATEGORY: <trust-boundary|resource-leak|
               race-condition|input-validation|
               error-handling|state-corruption|other>
    ISSUE: <one-line summary>
    DETAIL: <explanation — as long as needed>
    RECOMMENDATION: <concrete fix>

If there are no material findings, return:

    NO_FINDINGS: Code review found no material issues.

Code to review:

<INSERT PACKAGED CONTEXT HERE>
---

Collect codex output. If the script fails or exits
non-zero, fall back to claude-only mode and warn
the user.

### Step 4: Cross-Validation

Skip if `--quick` flag is set or if operating in
claude-only mode. If skipping, go to Step 5.

**Normalize before cross-injection.** Parse both
models' findings into finding-schema objects. Never
pass raw prose from one model into another model's
prompt. Each validator sees only the structured
finding list and the referenced code.

Run both validations in parallel:

**Claude validates codex findings:**

Read the validator role skill verbatim:
`${CLAUDE_PLUGIN_ROOT}/skills/validator/SKILL.md`

Dispatch a **validator** agent (`subagent_type:
reviewer`) with:
- The validator skill content (verbatim)
- Codex's normalized findings (structured list)
- The packaged code context
- Instruction to append STATUS and NOTES to each
  finding

**Codex validates Claude findings:**

Shell out to the codex companion script:

```bash
node <codex-script-path> task --wait "<prompt>"
```

Use this prompt template:

---
**Codex Validation Prompt Template**

You are validating code review findings produced by
another model. For each finding, determine whether
it is correct by reading the actual code.

Rules:
- Do NOT modify any files
- Do NOT write code fixes
- Do NOT confirm findings out of politeness
- If a finding misreads the code, say so directly
- If you cannot verify a finding from the code you
  can see, mark it UNCERTAIN — do not guess

For each finding below:
1. Read the actual code at the FILE and LINES
   referenced in the finding.
2. Verify that the claim in ISSUE and DETAIL matches
   what the code does.
3. Check surrounding lines for context that might
   confirm or refute the claim.
4. If the finding references specific behavior (e.g.,
   "this loop iterates backwards"), verify the code
   does what the finding says.
5. Append STATUS and NOTES.

Return each finding with STATUS and NOTES appended.
Keep the original finding fields unchanged.

    FINDING: <original id>
    FILE: <original>
    LINES: <original>
    SEVERITY: <original>
    CATEGORY: <original>
    ISSUE: <original>
    DETAIL: <original>
    RECOMMENDATION: <original>
    STATUS: <CONFIRMED|DISPUTED|UNCERTAIN>
    NOTES: <your reasoning — required if DISPUTED,
            recommended for all>

Status meanings:
- CONFIRMED: You verified the issue exists in the
  code at the referenced location.
- DISPUTED: The finding is wrong or materially
  overstated. NOTES must explain what the finding
  got wrong.
- UNCERTAIN: Plausible but you cannot verify from
  the code available. NOTES should say what
  additional context would resolve it.

Findings to validate:

<INSERT NORMALIZED CLAUDE FINDINGS HERE>

Code context:

<INSERT PACKAGED CONTEXT HERE>
---

Collect both validation outputs and parse STATUS
fields for each finding.

### Step 4b: Reconciliation

Skip unless `--reconcile` flag is set. Requires
Step 4 to have run (incompatible with `--quick`).

For each finding with STATUS: DISPUTED, send the
original finding plus the validator's NOTES back to
the model that produced the finding. Use this prompt:

"Your finding was disputed by another reviewer:

<original finding in schema format>

Dispute reasoning:
<validator's NOTES>

Based on this dispute, do you:
(A) CONCEDE — the dispute is correct, withdraw
    the finding
(B) MAINTAIN — the finding stands, here is
    additional evidence: <explain>

Respond with CONCEDE or MAINTAIN and your reasoning."

**For Claude findings disputed by Codex:** dispatch
a general-purpose agent with the above prompt and
the packaged code context.

**For Codex findings disputed by Claude:** shell out
to codex `task --wait` with the above prompt and
the packaged code context.

Run all reconciliations in parallel.

**Processing results:**
- CONCEDE: remove the finding from the disputed list
- MAINTAIN: keep the finding in disputed, append the
  rebuttal reasoning alongside the original dispute

Max one round. No back-and-forth debate.

### Step 5: Merge and Output

Collect all findings and validation statuses. Choose
the output format based on mode (see Output Formats).

**Deduplication:** findings from both models that
describe the same issue at the same location count
as one finding. Use FILE + LINES + CATEGORY to
identify duplicates. Keep the finding with more
detail; note that both models flagged it.

**Fix list entries** (full and quick modes):
- Findings confirmed by both models in their initial
  reviews (shared findings)
- Findings unique to one model and CONFIRMED during
  cross-validation
- Sorted by SEVERITY (high → medium → low)

**Disputed entries:**
- Findings that received a DISPUTED verdict during
  cross-validation
- Include the dispute NOTES inline

**Uncertain entries:**
- Findings that received an UNCERTAIN verdict during
  cross-validation
- Include in the output for human triage — these are
  plausible issues the validator could not confirm
  or deny from available context

## Output Formats

### Full Mode (default)

Used when codex is available and `--quick` is not set.

```
## Cross-Review Results

Scope: <scope description>
Claude findings: <n> | Codex findings: <n> | Shared: <n>

### Fix List

<For each confirmed finding, in severity order:>

FINDING: <id>
FILE: <path>
LINES: <range>
SEVERITY: <level>
CATEGORY: <category>
ISSUE: <summary>
DETAIL: <explanation>
RECOMMENDATION: <fix>
CONFIRMED_BY: <claude|codex|both>

### Disputed Findings

Unverified — human review needed.

<For each disputed finding:>

FINDING: <id>
FILE: <path>
LINES: <range>
SEVERITY: <level>
CATEGORY: <category>
ISSUE: <summary>
DETAIL: <explanation>
RECOMMENDATION: <fix>
STATUS: DISPUTED
DISPUTE: <validator's NOTES explaining what is wrong>
REBUTTAL: <originator's response, if --reconcile was
          used and they chose MAINTAIN>

Note: if --reconcile was used, findings where the
originator conceded are removed from this list.

### Uncertain Findings

Could not verify — human triage needed.

<For each uncertain finding:>

FINDING: <id>
FILE: <path>
LINES: <range>
SEVERITY: <level>
CATEGORY: <category>
ISSUE: <summary>
DETAIL: <explanation>
RECOMMENDATION: <fix>
STATUS: UNCERTAIN
NOTES: <what additional context would resolve this>
```

### Quick Mode (`--quick`)

Used when `--quick` flag is set.

```
## Cross-Review Results (Quick)

Scope: <scope description>
Claude findings: <n> | Codex findings: <n>
Note: cross-validation skipped (--quick)

### Findings

<Union of all findings from both models,
deduplicated, sorted by severity.>

FINDING: <id>
FILE: <path>
LINES: <range>
SEVERITY: <level>
CATEGORY: <category>
ISSUE: <summary>
DETAIL: <explanation>
RECOMMENDATION: <fix>
SOURCE: <claude|codex|both>
```

### Claude-Only Mode

Used when codex is unavailable (script missing,
path not configured, or script exits non-zero).

```
## Cross-Review Results (Claude Only)

WARNING: Codex unavailable — findings are not
cross-validated. Configure codex-script in
CLAUDE.md to enable multi-model review.

Scope: <scope description>
Claude findings: <n>

### Findings

<All Claude findings, sorted by severity.>

FINDING: <id>
FILE: <path>
LINES: <range>
SEVERITY: <level>
CATEGORY: <category>
ISSUE: <summary>
DETAIL: <explanation>
RECOMMENDATION: <fix>
```
