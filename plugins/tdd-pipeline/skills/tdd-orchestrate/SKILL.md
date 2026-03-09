---
name: tdd-orchestrate
description: >
  Run the TDD pipeline for a module. Use when asked to
  "use TDD", "red green TDD", "run the pipeline",
  "TDD pipeline", "build a module with TDD", or
  "orchestrate".
  Dispatches 7 agents
  across separate stages: test writer, test reviewer,
  red gate, implementer, verify gate, code reviewer,
  integrate.
user-invocable: true
---

# /tdd-orchestrate

Run the 7-stage TDD pipeline for a module.

## Input

Module: $0

If no module name was provided above, ask the user for
the module name and behavior list before proceeding.

If a module name was provided but no behavior list, ask
the user for the behavior list.

Example invocation: `/tdd-orchestrate parser`

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
