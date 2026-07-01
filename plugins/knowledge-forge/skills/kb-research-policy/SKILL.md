---
name: kb-research-policy
user-invocable: true
description: >
  Routing and retrieval policy for your personal
  knowledge base at ~/code/knowledge (or the
  knowledge-base: path in the active project CLAUDE.md).
  Use when the user asks about past research, prior
  notes, captured sources, topics they have studied, or
  anything that might live in a personal wiki of
  synthesized notes. Triggers on phrases like "what do
  we know about", "check my notes", "any research on",
  "from the KB", "have I looked into", "do I have notes
  on". Tells you to read the cheap index/ files first,
  then query via the qmd MCP server (lex for known
  terms, vec for fuzzy), then open full notes only once
  the shortlist is small. Also the entry point for
  answering "is my KB healthy?" — points at just check.
---

# KB Research Policy

Travis maintains a three-layer personal knowledge base.
This skill tells you how to find things in it efficiently
from any session, regardless of your current working
directory.

The three layers:

- `raw/` — immutable source archive (web crawls, PDFs,
  snapshots). Never edit.
- `wiki/` — synthesized notes in buckets: `sources/`,
  `concepts/`, `reports/`, `questions/`, `projects/`,
  `playbooks/`, `dependencies/`.
- `index/` — cheap one-line-per-entry routing files.
  Read these first.

For edge cases not covered here, read `<kb>/CLAUDE.md`
and `<kb>/AGENTS.md` directly.

---

## Step 1: Resolve the KB path

Run `${CLAUDE_PLUGIN_ROOT}/scripts/resolve-kb-path.sh` and
capture its stdout as `kb_path`. Every subsequent command
uses `"$kb_path"` (double-quoted).

```bash
kb_path=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-kb-path.sh")
```

If the script exits non-zero, relay its stderr message to
the user verbatim and stop — do not guess a fallback path.

---

## Step 2: Read the index first

Index files are small (one line per entry) and are the
cheapest first hop. Read only the ones relevant to the
question. Do not open full wiki notes yet.

Current index files under `<kb>/index/`:

- `sources.md` — web pages and docs Travis has read
- `concepts.md` — synthesized topic pages
- `open-questions.md` — unresolved inquiries
- `playbooks.md` — reusable how-to notes
- `projects.md` — project overviews
- `dependencies.md` — external tools and libraries
- `doc-packs.md` — downloaded external doc packs (AUTO-GENERATED)
- `freshness.md` — last updated_at per external source (AUTO-GENERATED)
- `authoritative-files.md` — canonical file references

If a listed index file does not exist, skip it silently.
Not every KB populates every bucket.

After reading the relevant index files, you should have
a shortlist of candidate note IDs. If the index alone
gives a confident, complete answer, you may skip Step 3
and answer directly. Otherwise proceed to Step 3 — the
hand-maintained index can lag actual note content, so a
thin or stale-looking index entry is not itself a
complete answer.

---

## Step 3: Search with qmd MCP

Use the qmd MCP server to search across notes. Always
pass `intent` so snippets are tuned to the question.

**For exact terms and known IDs — use lex (BM25):**

```
mcp__plugin_qmd_qmd__query(
  searches=[{type:'lex', query:'<exact term>'}],
  intent='<what you are looking for>',
  collection='knowledge-wiki'
)
```

**For fuzzy or semantic questions — add vec:**

```
mcp__plugin_qmd_qmd__query(
  searches=[
    {type:'lex', query:'<term>'},
    {type:'vec', query:'<question phrased as prose>'}
  ],
  intent='<what you are looking for>',
  collection='knowledge-wiki'
)
```

**Collection scoping:**

- Query both `knowledge-wiki` and `knowledge-external` by
  default — most questions can draw on either.
- Restrict to `knowledge-external` only when the user
  explicitly asks what the docs say (upstream
  documentation only, not Travis's own notes).
- Restrict to `knowledge-wiki` only when the user
  explicitly asks what they themselves have concluded
  (their synthesis only, not raw upstream docs).

**Filter low-confidence results** with `minScore: 0.5`
when results are noisy. Treat 0.5 as a starting heuristic,
not a fixed constant — adjust it as the corpus grows.

---

## Step 4: Open full notes only after shortlisting

Once the index and search results give you a small
candidate list, retrieve full notes:

```
mcp__plugin_qmd_qmd__get(path='wiki/sources/...')
mcp__plugin_qmd_qmd__multi_get(paths=['a.md', 'b.md'])
```

Do not open full notes before you have a shortlist.
Opening notes blindly wastes context and gives worse
answers.

---

## Health checks

If the user asks whether the KB is healthy:

```bash
cd "$kb_path" && just check
```

This runs `scripts/lint-frontmatter` (frontmatter
validity, wikilink resolution, raw_path existence) and
`scripts/validate-qmd` (retrieval harness).

If content has changed and needs reindexing:

```bash
cd "$kb_path" && just refresh
```

This runs `gen-indexes` → `shape` → `qmd update` →
`qmd embed` → `validate-qmd` in sequence.

---

## Anti-patterns

- **Do not** open full notes before reading the index
  and getting a shortlist.
- **Do not** run `qmd` CLI commands if the MCP server
  is available — prefer `mcp__plugin_qmd_qmd__*`.
- **Do not** hand-edit `index/doc-packs.md` or
  `index/freshness.md` — they are auto-generated by
  `scripts/gen-indexes`.
- **Do not** substitute a web search for a KB lookup
  when the KB likely has the answer. Ask Travis if
  unsure whether a topic is captured.
- **Do not** write to `raw/` — that layer is the ingest
  archive, maintained by `scripts/ingest-web`.
