---
name: kb-ingest
description: >
  Download an external documentation site into your
  personal knowledge base as a doc pack and source note.
  Use when the user says "/kb-ingest <url>", "ingest
  these docs", "add these docs to the KB", or "download
  reference docs". Runs webdown crawl via the knowledge
  repo's ingest-pack recipe, then creates a MANIFEST.md
  and source note automatically.
user-invocable: true
---

# /kb-ingest

Download an external documentation site into the
personal knowledge base as a doc pack and source note.
Safe to run from any working directory.

## Input

Scope: $ARGUMENTS

Two forms:

**Web crawl:** `<url> [category] [tool] [version]
[path_prefix] [selector]`

**Local copy:** `<local-path> [category] [tool] [version]`

- `url` or `local-path` — required. An `https://` URL
  to crawl, or an absolute/relative path to a local
  directory of already-downloaded docs.
- `category` — optional. Where in `raw/external/` to
  file the pack (e.g. `providers`, `tooling`,
  `protocols`, `languages`, `libraries`).
- `tool` — optional. Tool/service name slug (e.g.
  `fastmail`, `jmap`, `uv`).
- `version` — optional. Defaults to `latest`.
- `path_prefix` — optional (web only). Limits crawl to
  URLs with this prefix. Leave empty to crawl from root.
- `selector` — optional (web only). CSS selector for
  content extraction. Defaults to `main`.

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

## Step 2: Parse arguments and classify

Extract the first token from `$ARGUMENTS`. Detect mode:

- If it starts with `/`, `~/`, or `./` → **local mode**
  (copy from a local directory; skip the web crawl)
- Otherwise → **web mode** (crawl from the URL)

In local mode, resolve the source path:
```bash
src_path=$(realpath "$first_token" 2>/dev/null)
[ -d "$src_path" ] || { echo "Source path not found"; exit 1; }
```

If `category` and `tool` are not provided, derive them
from the URL domain (web mode) or ask once (local mode):


| Domain | category | tool |
|---|---|---|
| `fastmail.com` | `providers` | `fastmail` |
| `jmap.io` | `protocols` | `jmap` |
| `anthropic.com` | `providers` | `anthropic` |
| `openai.com` | `providers` | `openai` |
| `docs.*.com` or similar | ask | ask |

When unable to classify from the domain, use
AskUserQuestion once:

> "What category and tool name should I use for
> `<domain>`? (e.g. `providers fastmail`,
> `tooling uv`, `protocols jmap`)"

If you had to ask, suggest the user add a row to the
domain table above for next time.

Default `version` to `latest` if omitted.
Default `selector` to `main` if omitted.
Default `path_prefix` to `""` (empty) if omitted.

---

## Step 3: Check for existing pack

```bash
pack_dir="$kb_path/raw/external/$category/$tool/$version"
if [ -d "$pack_dir" ]; then
  echo "Warning: pack already exists at $pack_dir"
  echo "Re-ingest will overwrite changed files."
fi
```

If the pack directory exists, read its
`"$pack_dir/MANIFEST.md"` before overwriting. If its
`status:` field is `stable`, use AskUserQuestion to
confirm with the user before proceeding — a stable pack
has been reviewed and re-ingesting silently could discard
that review. Auto-proceed without asking when `status` is
`fresh`, or when MANIFEST.md does not exist.

---

## Step 4: Populate the pack directory

**Web mode** — crawl the URL:

```bash
today=$(date +%Y-%m-%d)
cd "$kb_path" && just ingest-pack \
  "$category" "$tool" "$version" "$url" \
  "$path_prefix" "$selector"
```

If the crawl produces no files (or only tiny stubs),
the site likely requires JS rendering, or the selector
did not match. Retry with the next selector in this fixed
order, stopping at the first one that produces real
content: `main` → `article` → `.content` → `body`. If all
four fail, stop and report the failure to the user with
the selectors you tried.

**Local mode** — copy from the existing directory:

```bash
today=$(date +%Y-%m-%d)
mkdir -p "$pack_dir"
cp -r "$src_path/." "$pack_dir/"
```

This copies the already-downloaded docs into
`raw/external/<category>/<tool>/<version>/` without
making any network requests.

---

## Step 5: List the pack directory

```bash
find "$pack_dir" -name "*.md" | sort
```

Record the file list. You will use it in the MANIFEST
and source note.

---

## Step 6: Write MANIFEST.md

Use the **Write tool** to create
`"$pack_dir/MANIFEST.md"`. This is what `gen-indexes`
reads to populate `index/doc-packs.md`.

```yaml
---
id: pack-<tool>-<version>
type: doc-pack
name: <Human-Readable Name>
category: <category>
version: <version>
variant: current
source_urls:
  - <url>
ingest_method: webdown
downloaded_at: <today>
reviewed_at: <today>
status: fresh
related_projects: []
---

# <Human-Readable Name> doc pack

## Local files

- <one bullet per .md file from the directory listing>
```

ID pattern: `pack-<tool>-<version>` (e.g.
`pack-fastmail-latest`, `pack-jmap-latest`).

Fill `related_projects` if the current session has an
obvious project (e.g. building a Fastmail MCP server →
add that project slug). Leave `[]` if unknown.

---

## Step 7: Write source note

Compute the source note path:
`"$kb_path/wiki/sources/external/<category>/source-<tool>-<version>.md"`

This matches kb-capture's source-note destination
(`wiki/sources/external/<category>/<slug>.md`), so
ingested and captured source notes share one layout.

If that path already exists, append `-2`, `-3`, … to
the slug until free.

Use the **Write tool**:

```yaml
---
id: source-<tool>-<version>
type: source
title: <Human-Readable Name> Official Docs
summary: <2-3 sentences covering what the docs contain
  and why they are useful in this KB>
topics: [3-5 kebab-case terms]
sources: []
aliases: []
status: draft
updated_at: <today>
raw_path: raw/external/<category>/<tool>/<version>
url: <url>
---

# <Human-Readable Name> Official Docs

## Why it matters

<One paragraph: why these docs were ingested and which
projects or tasks in this KB rely on them>

## Best current files

<Curated list of 3-8 files from the directory listing
that are most useful for navigation — not every file>
```

Use the compact format of existing external source
notes (see `wiki/sources/external/source-github-cli-
latest.md` for the pattern). Do not use the full
source-note template sections (Abstract, Key claims,
etc.). If that file does not exist in this KB, use any
existing file under `wiki/sources/external/` as the
pattern reference instead.

---

## Step 8: Validate with just lint

```bash
cd "$kb_path" && just lint
```

The linter checks that `raw_path` exists on disk — this
will pass since the pack was crawled in step 4. Fix any
failure before proceeding.

---

## Step 9: Reindex with just refresh

```bash
cd "$kb_path" && just refresh
```

This runs `gen-indexes` → `shape` → `qmd update` →
`qmd embed` → `validate-qmd` in sequence.

If `validate-qmd` fails, surface the output to the user
and stop. Do not auto-fix retrieval regressions.

---

## Step 10: Update index/sources.md

Append one line to `"$kb_path/index/sources.md"`:

```
- `source-<tool>-<version>` — <short description>.
  (`wiki/sources/external/<category>/source-<tool>-<version>.md`)
```

---

## Step 11: Report

Print:

- Pack path and file count
- Source note ID and full absolute path
- Lint result (pass, or failures fixed)
- Refresh result (pass/fail + any warnings)
- One sentence on what was ingested

---

## Anti-patterns

- **Do not crawl without a path_prefix when the site
  has broad navigation.** Sites like jmap.io include
  blog, news, and press pages at the root. Without a
  prefix, the crawl will pull in off-topic content that
  pollutes retrieval. Check the site structure and scope
  to the docs subtree.
- **Do not edit files in `raw/`.** They are the
  immutable source archive. Write MANIFEST.md there
  (it is metadata, not a crawled page), but never edit
  the crawled `.md` files.
- **Do not skip MANIFEST.md.** `gen-indexes` reads it
  to populate `index/doc-packs.md`. Without it the pack
  is invisible to the auto-generated index.
- **Do not set `status: stable`** on first ingest. Use
  `fresh`; Travis promotes to `stable` manually after
  review.
- **Verify crawl output before writing source note.**
  Files under ~500 bytes after crawl are likely empty
  shells from a JS-rendered site. Try a different
  selector before filing the note.
