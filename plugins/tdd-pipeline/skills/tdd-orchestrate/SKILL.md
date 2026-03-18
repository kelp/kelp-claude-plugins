---
name: tdd-orchestrate
description: >
  Enforce strict red-green-refactor TDD for any task.
  Use when implementing features, fixing bugs, adding
  functionality, or building new modules. Routes to the
  full 7-agent pipeline for new modules with 3+ behaviors,
  or runs inline red-green-refactor for bug fixes and
  small changes. Triggers on: "use TDD", "fix this bug",
  "add a feature", "implement", "run the pipeline",
  "TDD pipeline", "build a module with TDD", or any
  coding task in a project with TDD in its CLAUDE.md.
user-invocable: true
---

# /tdd-orchestrate

Strict red-green-refactor for every code change.

## Input

Task: $0

If no task was provided, ask the user what to implement
or fix. One sentence is enough.

## Decide: Pipeline or Inline

**Use the full pipeline** (see "Pipeline" section) when:
- Building a new module from scratch
- The task has 3+ distinct behaviors to implement
- The user explicitly asks for the pipeline

**Use inline red-green-refactor** when:
- Fixing a bug
- Adding a single feature or flag
- Modifying existing code
- The change touches 1-2 files

Most tasks are inline. Default to inline unless the
scope clearly warrants the full pipeline.

## Inline Red-Green-Refactor

### Step 1: Understand (< 2 minutes)

Read the relevant source and test files. Identify where
the change goes. Do NOT write a plan document or
summarize what you're about to do — read the code and
move to step 2.

If you catch yourself writing a plan, outlining an
approach, or explaining what you will do: STOP. Write
a test instead.

### Step 2: RED — Write a failing test

Write a test against the REAL production code. Import
the actual module. Call the actual function. Assert the
behavior you want.

Run the test. It must fail. If it passes, either the
feature already exists or your test doesn't exercise
what you think it does. Investigate before proceeding.

**The test must fail for the RIGHT reason.** A compile
error or import failure is not a valid red state — fix
those first so the test runs and fails on the assertion.

### Step 3: GREEN — Minimal implementation

Write the smallest change to make the test pass. No
refactoring. No cleanup. No extra features. Just make
the red test turn green.

Run the test. If it fails, fix the implementation (not
the test) until it passes.

Run the FULL test suite. If other tests broke, fix the
implementation until everything passes.

### Step 4: REFACTOR (only if needed)

If the code is clear and clean, skip this step. If you
refactor, run the full test suite after every change.

### Step 5: Commit

Commit with a descriptive message. One logical change
per commit.

### Repeat

If the task requires multiple changes, repeat from
step 2 for each behavior. One test-implement cycle
per behavior.

## Common Mistakes

These are real mistakes from past sessions. Each one
wastes significant time.

**Don't test duplicated logic.** Your test must import
and call the production code. If your test reimplements
the logic it's supposed to verify, it proves nothing.

**Don't skip the red step.** Every test must fail before
you write implementation code. Writing the test and
implementation together means you don't know whether the
test catches regressions.

**Don't get stuck planning.** The plan is: write a
failing test. If you've spent more than 2 minutes
without creating or editing a test file, you're stalling.

**Don't test the wrong file descriptor.** When testing
TTY behavior, verify which fd (stdin, stdout, stderr)
the code actually checks.

**Don't mock what you can call.** If the real code is
available and fast, call it. Mocks diverge from
production and hide bugs.

---

## Full Pipeline

Use this section when the routing decision above chose
the full pipeline. For inline tasks, ignore everything
below.

### Pipeline Input

If the task specifies a module name, use it. Otherwise,
ask the user for the module name and behavior list.

Example: `/tdd-orchestrate parser`

## The Rule

**You are a PURE DISPATCHER. You NEVER write code.**

Violations you MUST NOT commit:
- Writing or editing any source or test file
- Fixing compiler errors or test failures directly
- Modifying code "just to unblock" something
- Making "small" fixes that "aren't worth an agent"
- Skipping any stage of the pipeline

What you DO:
- Dispatch agents with the correct role skill
- Run verify gate checks between stages
- Update build files after approval (if needed)
- Run full test suite and commit
- Escalate to user after 3 agent rejections

If you catch yourself about to use Write or Edit on
a source or test file, STOP. Dispatch an agent.

## Red Flags -- You Are Skipping the Pipeline

- "I'll write both tests and code in one agent"
- "This module is simple enough to skip review"
- "Let me just fix this one test real quick"
- "The test-writer can also stub the implementation"
- "We don't need to run tests before implementing"
- "The stubs are trivial, RED gate is unnecessary"

All of these mean STOP. Follow the pipeline.

## Dispatching Agents

Use the Agent tool to launch sub-agents. Before
dispatching, read the skill files from this plugin
and include their content verbatim in the agent
prompt:

- `${CLAUDE_PLUGIN_ROOT}/skills/test-writer/SKILL.md`
- `${CLAUDE_PLUGIN_ROOT}/skills/test-reviewer/SKILL.md`
- `${CLAUDE_PLUGIN_ROOT}/skills/implementer/SKILL.md`
- `${CLAUDE_PLUGIN_ROOT}/skills/code-reviewer/SKILL.md`
- `${CLAUDE_PLUGIN_ROOT}/skills/agent-briefing/SKILL.md`

Agent types:
- **programmer** agents: use `subagent_type: programmer`
- **reviewer** agents: use `subagent_type: reviewer`

## Pipeline

Read the project's CLAUDE.md for test commands, file
paths, and language-specific context. Every value
below marked with `(CLAUDE.md)` must come from there.

### Stage 1: Test Writer

Dispatch a **programmer** agent with:
- The `test-writer` skill content
- The `agent-briefing` skill content
- Module name and behavior list
- Type signatures and dependency APIs
- Test command (CLAUDE.md)

The agent writes the test file and type stubs to the
source file path (CLAUDE.md). Stubs contain only
signatures -- no real logic.

### Stage 2: Test Reviewer

Dispatch a **reviewer** agent with:
- The `test-reviewer` skill content
- Module name and behavior list
- The test file path

**Fix loop**: if NEEDS_FIXES, dispatch a **programmer**
agent with the `test-writer` skill and the reviewer's
feedback as the fix list. Then re-dispatch the
reviewer. Max 3 rounds, then escalate to user.

### Stage 3: Red Gate

Run the module test command (CLAUDE.md).

- Tests must COMPILE and all must FAIL at runtime.
- A compile error is NOT a pass -- re-dispatch the
  test-writer to fix stubs until tests compile.
- If any test passes, the stubs contain real logic.
  Re-dispatch the test-writer to strip stubs back
  to signatures only.

Only proceed when tests compile and all fail.

### Stage 4: Implementer

Dispatch a **programmer** agent with:
- The `implementer` skill content
- The `agent-briefing` skill content
- Module name and behavior list
- Type signatures and dependency APIs
- Test command (CLAUDE.md)

The agent replaces the stub source file with the
real implementation to make all tests pass.

### Stage 5: Verify Gate

Run these checks yourself (do NOT dispatch an agent):

1. Module test command passes (CLAUDE.md)
2. Source file > 30 lines (catches stubs -- adjust
   threshold per CLAUDE.md if your language is terse)
3. Lint command passes (CLAUDE.md)
4. Language-specific checks pass (CLAUDE.md)

If any check fails: re-dispatch implementer with
specific feedback. Do NOT waste a reviewer dispatch.

### Stage 6: Code Reviewer

Dispatch a **reviewer** agent with:
- The `code-reviewer` skill content
- Module name and behavior list
- Source and test file paths

**Fix loop**: if NEEDS_FIXES, dispatch a **programmer**
agent with the `implementer` skill and the reviewer's
feedback as the fix list. Then re-dispatch the
reviewer. Max 3 rounds, then escalate to user.

### Stage 7: Integrate

After code reviewer approves:
1. Update build files if needed (CLAUDE.md)
2. Run full test command (CLAUDE.md)
3. Commit with a descriptive message
