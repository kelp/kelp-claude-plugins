# Marketplace Restructure Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use
> superpowers:executing-plans to implement this plan
> task-by-task.

**Goal:** Restructure zig-claude-kit into a monorepo
plugin marketplace with SessionStart hook and /zig-init
skill for automatic correction delivery.

**Architecture:** Monorepo marketplace with plugins/
subdirectory. Each plugin is self-contained with its own
manifest, skills, hooks, and docs. The marketplace.json
at root catalogs all plugins.

**Tech Stack:** Claude Code plugin system, bash hooks,
markdown skills

---

### Task 1: Create plugin directory and move existing files

**Files:**
- Create: `plugins/zig-claude-kit/` directory tree
- Move: all existing plugin files into it

**Step 1: Create the plugin directory structure**

```bash
mkdir -p plugins/zig-claude-kit/.claude-plugin
mkdir -p plugins/zig-claude-kit/hooks
mkdir -p plugins/zig-claude-kit/skills
mkdir -p plugins/zig-claude-kit/docs
mkdir -p plugins/zig-claude-kit/scripts
```

**Step 2: Move existing files with git mv**

```bash
git mv skills/zig-patterns plugins/zig-claude-kit/skills/
git mv skills/zig-check plugins/zig-claude-kit/skills/
git mv docs/ZIG_BREAKING_CHANGES.md \
  plugins/zig-claude-kit/docs/
git mv scripts/zig-knowledge-audit.sh \
  plugins/zig-claude-kit/scripts/
git mv scripts/zig-knowledge-eval.py \
  plugins/zig-claude-kit/scripts/
git mv scripts/zig-knowledge-prompts.md \
  plugins/zig-claude-kit/scripts/
git mv scripts/zig-knowledge-test.sh \
  plugins/zig-claude-kit/scripts/
git mv probes plugins/zig-claude-kit/probes
git mv justfile plugins/zig-claude-kit/justfile
git mv README.md plugins/zig-claude-kit/README.md
git mv .claude-plugin/plugin.json \
  plugins/zig-claude-kit/.claude-plugin/plugin.json
```

**Step 3: Remove empty directories**

```bash
rmdir skills scripts docs .claude-plugin
```

**Step 4: Commit**

```bash
git add -A
git commit -m "Move existing files into plugins/zig-claude-kit/"
```

---

### Task 2: Create the CLAUDE.md fragment

The current root CLAUDE.md becomes a fragment designed
to be appended to any project's CLAUDE.md.

**Files:**
- Create: `plugins/zig-claude-kit/docs/claude-md-fragment.md`
- Remove: `CLAUDE.md` (root)

**Step 1: Create the fragment file**

Write `plugins/zig-claude-kit/docs/claude-md-fragment.md`
with this content — the same corrections from the current
CLAUDE.md, formatted as an appendable section:

```markdown
## Zig 0.15.x Training Corrections

Your Zig training is outdated. This project uses Zig 0.15.x
with breaking changes that affect code you generate by default.

### The 6 Patterns You Get Wrong

Before writing ANY Zig code, internalize these corrections:

1. `std.io.getStdOut()` / `getStdErr()` -- **removed**
   (Writergate). Use buffered writer pattern.
2. `build.zig` uses `.root_module = b.createModule(...)` --
   not bare `.root_source_file`.
3. Format method signature changed; `{}` requires `{f}` to
   call format methods.
4. `usingnamespace` -- **removed** from language entirely.
5. `std.BoundedArray` -- **removed**. Use
   `ArrayListUnmanaged.initBuffer`.
6. `std.ArrayList(T).init(allocator)` -- **removed**. Use
   `std.ArrayListUnmanaged(T){}` with allocator per call.

### I/O Pattern (Writergate) -- Memorize This

` ``zig
// WRONG: std.io.getStdOut().writer()
// RIGHT:
var stdout_buffer: [4096]u8 = undefined;
var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
const stdout = &stdout_writer.interface;
defer stdout.flush() catch {};

try stdout.print("Hello, {s}\n", .{name});
` ``

Always `defer flush() catch {}` or data is lost.

### build.zig Pattern

` ``zig
// WRONG:
// const exe = b.addExecutable(.{
//     .name = "app",
//     .root_source_file = b.path("src/main.zig"),
//     .target = target,
//     .optimize = optimize,
// });

// RIGHT:
const exe = b.addExecutable(.{
    .name = "app",
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    }),
});
` ``

### Quick Lookup

When you hit a compile error, run
`/zig-claude-kit:zig-patterns` for the full reference.
```

**Step 2: Remove the root CLAUDE.md**

```bash
git rm CLAUDE.md
```

**Step 3: Commit**

```bash
git add plugins/zig-claude-kit/docs/claude-md-fragment.md
git commit -m "Convert CLAUDE.md to appendable fragment"
```

---

### Task 3: Create the SessionStart hook

**Files:**
- Create: `plugins/zig-claude-kit/hooks/hooks.json`
- Create: `plugins/zig-claude-kit/scripts/session-start.sh`

**Step 1: Write hooks.json**

Write `plugins/zig-claude-kit/hooks/hooks.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/session-start.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

**Step 2: Write session-start.sh**

Write `plugins/zig-claude-kit/scripts/session-start.sh`:

```bash
#!/bin/bash
# Detect Zig projects missing 0.15.x corrections.
# Runs at Claude Code session start via plugin hook.

# Only act in Zig projects
if [ ! -f "build.zig" ] && \
   ! compgen -G "*.zig" > /dev/null 2>&1 && \
   ! compgen -G "src/*.zig" > /dev/null 2>&1; then
  exit 0
fi

# Check if corrections already present
if grep -q "Writergate" CLAUDE.md 2>/dev/null; then
  exit 0
fi

echo "This is a Zig project missing Zig 0.15.x corrections in CLAUDE.md."
echo "Run /zig-claude-kit:zig-init to add them."
exit 0
```

**Step 3: Make script executable**

```bash
chmod +x plugins/zig-claude-kit/scripts/session-start.sh
```

**Step 4: Commit**

```bash
git add plugins/zig-claude-kit/hooks/hooks.json \
  plugins/zig-claude-kit/scripts/session-start.sh
git commit -m "Add SessionStart hook for Zig project detection"
```

---

### Task 4: Create the /zig-init skill

**Files:**
- Create: `plugins/zig-claude-kit/skills/zig-init/SKILL.md`

**Step 1: Write the skill**

Write `plugins/zig-claude-kit/skills/zig-init/SKILL.md`:

```markdown
---
description: >
  Add Zig 0.15.x training corrections to this project's
  CLAUDE.md. Run this in any Zig project to fix Claude's
  outdated patterns for I/O, ArrayList, format strings,
  build.zig, BoundedArray, and usingnamespace.
---

# /zig-init

Add Zig 0.15.x corrections to this project's CLAUDE.md.

## Procedure

### 1. Read the corrections fragment

Read the file at
`${CLAUDE_PLUGIN_ROOT}/docs/claude-md-fragment.md`.
This contains the Zig 0.15.x training corrections
formatted as a CLAUDE.md section.

### 2. Check current CLAUDE.md

- If no `CLAUDE.md` exists in the project root, create
  one with just a `# CLAUDE.md` header followed by the
  fragment content.
- If `CLAUDE.md` exists, check if it already contains
  "Writergate". If so, report "Zig corrections already
  present" and stop.
- If `CLAUDE.md` exists but lacks the corrections,
  append the fragment content to the end of the file.

### 3. Report result

Tell the user what you did:
- "Created CLAUDE.md with Zig 0.15.x corrections"
- "Added Zig 0.15.x corrections to existing CLAUDE.md"
- "Zig corrections already present in CLAUDE.md"
```

**Step 2: Commit**

```bash
git add plugins/zig-claude-kit/skills/zig-init/SKILL.md
git commit -m "Add /zig-init skill for CLAUDE.md injection"
```

---

### Task 5: Update plugin.json

**Files:**
- Modify: `plugins/zig-claude-kit/.claude-plugin/plugin.json`

**Step 1: Update plugin.json with hooks reference**

Write `plugins/zig-claude-kit/.claude-plugin/plugin.json`:

```json
{
  "name": "zig-claude-kit",
  "description": "Corrective context for Zig 0.15.x that fixes Claude's outdated training data. Covers I/O (Writergate), build.zig, format strings, ArrayList, BoundedArray, and usingnamespace.",
  "version": "1.0.0",
  "author": {
    "name": "Travis Cole"
  },
  "homepage": "https://github.com/kelp/kelp-claude-plugins",
  "repository": "https://github.com/kelp/kelp-claude-plugins",
  "hooks": "./hooks/hooks.json"
}
```

**Step 2: Commit**

```bash
git add plugins/zig-claude-kit/.claude-plugin/plugin.json
git commit -m "Add hooks reference to plugin.json"
```

---

### Task 6: Create marketplace.json

**Files:**
- Create: `.claude-plugin/marketplace.json`

**Step 1: Create the marketplace directory and manifest**

```bash
mkdir -p .claude-plugin
```

Write `.claude-plugin/marketplace.json`:

```json
{
  "name": "kelp-claude-plugins",
  "owner": {
    "name": "Travis Cole",
    "email": "kelp@plek.org"
  },
  "metadata": {
    "description": "Claude Code plugins by kelp",
    "version": "1.0.0"
  },
  "plugins": [
    {
      "name": "zig-claude-kit",
      "source": "./plugins/zig-claude-kit",
      "description": "Corrective context for Zig 0.15.x that fixes Claude's outdated training data. Covers I/O (Writergate), build.zig, format strings, ArrayList, BoundedArray, and usingnamespace.",
      "version": "1.0.0",
      "strict": true
    }
  ]
}
```

**Step 2: Commit**

```bash
git add .claude-plugin/marketplace.json
git commit -m "Add marketplace manifest"
```

---

### Task 7: Write new root README and update .gitignore

**Files:**
- Create: `README.md`
- Modify: `.gitignore`

**Step 1: Write the marketplace README**

Write `README.md`:

```markdown
# kelp-claude-plugins

Claude Code plugins by kelp.

## Installation

Add this marketplace to Claude Code:

` ``bash
/plugin marketplace add kelp/kelp-claude-plugins
` ``

## Available Plugins

### zig-claude-kit

Corrective context for Zig 0.15.x that fixes Claude's
outdated training data. Covers I/O (Writergate),
build.zig, format strings, ArrayList, BoundedArray, and
usingnamespace.

` ``bash
/plugin install zig-claude-kit@kelp-claude-plugins
` ``

Once installed, open any Zig project. The plugin detects
it at session start and prompts you to run `/zig-init`,
which adds the corrections to your project's CLAUDE.md.

**Skills:**
- `/zig-claude-kit:zig-patterns` -- Quick reference for
  correct Zig 0.15.x patterns
- `/zig-claude-kit:zig-check` -- Audit Zig files for
  common mistakes
- `/zig-claude-kit:zig-init` -- Add corrections to
  project CLAUDE.md

See [plugins/zig-claude-kit/](plugins/zig-claude-kit/)
for full documentation.

## License

Public domain. Use however you like.
```

**Step 2: Update .gitignore if needed**

Verify `.gitignore` still makes sense. Current content
is just `probes/` which now lives under the plugin.
Update to ignore at the plugin level:

```
plugins/*/probes/
```

**Step 3: Commit**

```bash
git add README.md .gitignore
git commit -m "Add marketplace README and update .gitignore"
```

---

### Task 8: Update zig-claude-kit README

**Files:**
- Modify: `plugins/zig-claude-kit/README.md`

**Step 1: Update the plugin README**

Update the README to reflect that this is now a plugin
within the marketplace. Remove the old "Option A / Option
B" install instructions. Replace with marketplace install
instructions and explain the SessionStart hook + /zig-init
flow.

Keep the eval/testing section but update paths to be
relative to the plugin directory.

**Step 2: Commit**

```bash
git add plugins/zig-claude-kit/README.md
git commit -m "Update zig-claude-kit README for marketplace"
```

---

### Task 9: Update justfile paths

**Files:**
- Modify: `plugins/zig-claude-kit/justfile`

**Step 1: Update script paths in justfile**

All script references need to be relative to the plugin
directory. Update paths from `scripts/` to `./scripts/`
and `probes/` to `./probes/` (they're already relative,
but verify they work from the plugin directory).

**Step 2: Verify justfile works**

```bash
cd plugins/zig-claude-kit && just --list
```

**Step 3: Commit if changes were needed**

```bash
git add plugins/zig-claude-kit/justfile
git commit -m "Update justfile paths for plugin directory"
```

---

### Task 10: Rename GitHub repo

**Step 1: Rename the repo**

```bash
gh repo rename kelp-claude-plugins
```

**Step 2: Update local git remote**

```bash
git remote set-url origin \
  git@github.com:kelp/kelp-claude-plugins.git
```

**Step 3: Verify**

```bash
git remote -v
gh repo view --json name,url
```

---

### Task 11: Verify the marketplace works

**Step 1: Test local plugin loading**

```bash
claude --plugin-dir ./plugins/zig-claude-kit
```

Start a session and verify:
- Skills show up (`/zig-claude-kit:zig-patterns`,
  `/zig-claude-kit:zig-check`, `/zig-claude-kit:zig-init`)
- SessionStart hook fires (check in a Zig project)

**Step 2: Push and test marketplace install**

```bash
git push
```

Then in a fresh Claude Code session:

```bash
/plugin marketplace add kelp/kelp-claude-plugins
/plugin install zig-claude-kit@kelp-claude-plugins
```

Verify the plugin installs and skills are available.
