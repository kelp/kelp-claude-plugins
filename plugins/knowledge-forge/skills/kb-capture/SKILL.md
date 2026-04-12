---
name: kb-capture
description: >
  Capture the current conversation, a source, or a
  synthesis into Travis's personal knowledge base as a
  well-formed wiki note. Writes correct frontmatter with
  today's date, picks the right bucket (sources/external,
  reports/, concepts/, questions/), cites existing source
  IDs, and runs just refresh to reindex afterward. Use
  when the user says "capture this", "save this to the
  KB", "add this as a note", "/kb-capture", or asks to
  file a finished research output.
user-invocable: true
---

# /kb-capture

Capture content into the personal knowledge base as a
well-formed wiki note. The command is safe to run from
any working directory.

## Input

Scope: $ARGUMENTS

- Empty → capture the current conversation as a report.
- Named file or URL → capture that source.
- Topic or title → use it as the note title; synthesize
  the body from the conversation.

---

## Step 1: Resolve the KB path

Run this shell block first. Every subsequent command uses
`"$kb_path"` (double-quoted).

```bash
kb_path=""
if [ -f CLAUDE.md ]; then
  raw=$(grep -E "^knowledge-base:" CLAUDE.md | head -1 \
    | sed 's/^knowledge-base://; s/^[[:space:]]*//; s/[[:space:]]*$//')
  if [ -n "$raw" ]; then
    kb_path=$(eval echo "$raw")
  fi
fi
if [ -z "$kb_path" ]; then
  kb_path="$HOME/code/knowledge"
fi
kb_path=$(realpath "$kb_path" 2>/dev/null) || {
  echo "knowledge-forge: cannot resolve KB path" >&2
  exit 1
}
case "$kb_path" in
  *$'\n'*|*$'\r'*|*$'\0'*|*\\*)
    echo "knowledge-forge: invalid characters in KB path" >&2
    exit 1 ;;
esac
if [ ! -f "$kb_path/justfile" ] || [ ! -d "$kb_path/index" ]; then
  echo "knowledge-forge: $kb_path is not a knowledge base" >&2
  exit 1
fi
```

---

## Step 2: Classify the note

Pick the note type. When ambiguous, use AskUserQuestion
once to clarify — do not guess.

| Type | When to use | Destination |
|---|---|---|
| `source` | Summary of one external artifact (article, doc, paper) | `wiki/sources/external/<category>/<slug>.md` |
| `concept` | Synthesized topic page citing multiple sources | `wiki/concepts/<slug>.md` |
| `report` | Deliverable, deep dive, or research output | `wiki/reports/<slug>.md` |
| `question` | Unresolved inquiry | `wiki/questions/<slug>.md` |

**Default when `$ARGUMENTS` is empty**: `report`.
Captured conversations are deliverables.

Source notes require `raw_path` (a file that already
exists under `<kb>/raw/`) and `url`. Do not classify
as `source` if you are not capturing a specific artifact
with a known raw file.

---

## Step 3: Build the slug

Rules:
- Lowercase, hyphen-separated words.
- Drop stopwords (a, the, an, of, for, in, on, with).
- Under 60 characters.
- Unique: if `<kb>/<bucket>/<slug>.md` already exists,
  append `-2`, `-3`, … until free.

Example: "Knowledge Forge Plugin Design" →
`knowledge-forge-plugin-design`.

---

## Step 4: Build the frontmatter

Get today's date:

```bash
today=$(date +%Y-%m-%d)
```

Read existing note IDs from the relevant index files
before writing `sources:`. Use only IDs you can confirm
exist — the linter rejects invented IDs.

```bash
cat "$kb_path/index/sources.md"
cat "$kb_path/index/concepts.md"
```

Frontmatter field order (do not reorder — the linter
is order-insensitive, but keeping order consistent
makes diffs readable):

```yaml
---
id: <type>-<slug>
type: <source|concept|report|question>
title: <human-readable title>
summary: <2-3 concrete sentences>
topics: [<kebab-case>, <kebab-case>, ...]
sources: [<existing-id>, ...]
aliases: []
status: draft
updated_at: <YYYY-MM-DD>
raw_path: <raw/...>      # source notes only — must exist on disk
url: <https://...>       # source notes only
---
```

Field rules:
- `topics`: 3–6 kebab-case items. Pick from existing
  topics where possible for consistency.
- `sources`: YAML inline list of existing note IDs.
  Empty list `[]` is fine for reports and questions
  with no direct citations.
- `aliases`: empty list `[]` unless the note has
  alternate names worth indexing.
- `status`: always `draft` on first capture.
- `raw_path`: source notes only. The path must exist
  on disk at `<kb>/<raw_path>`. Omit the field
  entirely for non-source notes.
- `url`: source notes only. Omit for non-source notes.

---

## Step 5: Draft the body

Use the matching template from `<kb>/templates/` as
the structural skeleton.

**Source note sections** (`templates/source-note.md`):

```
## Abstract
## Key claims
## Evidence / details
## Important quotes or passages
## Open questions
## Related concepts
```

**Concept note sections** (`templates/concept-note.md`):

```
## Summary
## Why it matters
## Supporting sources
## Tensions / disagreements
## Open questions
## Related concepts
```

**Report and question notes**: freeform, but must
include a `## Summary` section as the first section
after the title heading.

Write enough that the note is useful on retrieval.
A summary section of three or more sentences is the
minimum. Do not leave template placeholder text in the
body (no "<!-- fill in -->", no bullet points with just
a lone `-`).

---

## Step 6: Write the file

Compute the full path:

```
source:   <kb>/wiki/sources/external/<category>/<slug>.md
concept:  <kb>/wiki/concepts/<slug>.md
report:   <kb>/wiki/reports/<slug>.md
question: <kb>/wiki/questions/<slug>.md
```

For source notes, `<category>` matches the second path
segment of `raw_path` under `raw/external/` (e.g.,
`raw/external/languages/go/...` → category `languages`).

Use the **Write tool** with the resolved absolute path.
Do not use Bash to `cat >` or `echo >`.

---

## Step 7: Validate with just lint

```bash
cd "$kb_path" && just lint
```

If lint fails, read the output, fix the note, and run
lint again. Do not proceed to reindex with a failing
lint. Common failures:

- Missing required field → add it
- Broken `sources:` ID → remove or correct the ID
- Broken wikilink `[[id]]` → correct the link target
- `raw_path` missing on disk → verify the path

---

## Step 8: Reindex with just refresh

```bash
cd "$kb_path" && just refresh
```

This runs `gen-indexes` → `shape` → `qmd update` →
`qmd embed` → `validate-qmd` in sequence.

If `validate-qmd` fails, surface the output to the user
and stop. Do not auto-fix retrieval regressions —
that's for the user to decide.

---

## Step 9: Update hand-edited index files

`index/doc-packs.md` and `index/freshness.md` are
auto-generated by `gen-indexes` (called in step 8).
Do not edit them.

For all other index files, append a one-line entry if
the new note belongs there:

- `index/sources.md` → for every new source note
- `index/concepts.md` → for every new concept note
- `index/open-questions.md` → for every new question note
- `index/playbooks.md` → for playbook-type concept notes
- `index/reports.md` → for every new report note

Format: `- [title](../wiki/<bucket>/<slug>.md) — one
sentence hook`

---

## Step 10: Report

Print:

- Note ID and full absolute path
- Which bucket
- Lint result (pass, or how many failures fixed)
- Refresh result (pass/fail + any warnings)
- One sentence on what was captured

---

## Anti-patterns

- **Do not invent source IDs** in the `sources:` field.
  The linter checks that every ID in `sources:` resolves
  to an actual note's `id:` field. Invented IDs will
  fail lint.
- **Do not hand-edit** `index/doc-packs.md` or
  `index/freshness.md`. They are auto-generated.
- **Do not skip lint** (step 7) before reindexing.
  A note with broken frontmatter corrupts retrieval.
- **Do not write to `raw/`** via this skill. `raw/` is
  the ingest archive, populated by `scripts/ingest-web`.
- **Do not set `status: stable`** on a first capture.
  Use `draft`; Travis promotes to `stable` manually.
- **Do not write tool-keyword-dense bullet lists** in
  report bodies (e.g. listing every recipe or command
  by name). They pull retrieval rankings on unrelated
  queries about those tools. If you need to enumerate
  commands, link to the canonical doc instead.
