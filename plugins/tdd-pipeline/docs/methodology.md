# TDD Pipeline Methodology

## Overview

Seven-stage pipeline per module. Tests are written,
reviewed, and confirmed RED before implementation begins.

```
1. TEST WRITER (test-writer skill)
     Writes ALL tests + type stubs for the module.
     Tests compile. No real implementation.
       |
2. TEST REVIEWER (test-reviewer skill)
     Reviews tests for correctness and coverage.
       |
     fix loop: if issues found, dispatch fix agent,
     then re-review until APPROVED (max 3 rounds)
       |
3. RED GATE (orchestrator)
     Runs tests. ALL tests must FAIL. If any pass,
     the stubs are too complete -- re-dispatch
     test-writer to fix. This proves the tests
     actually exercise the implementation.
       |
4. IMPLEMENTER (implementer skill)
     Writes source code to make all tests pass.
     Cannot modify tests. Runs tests to confirm GREEN.
       |
5. VERIFY GATE (orchestrator)
     1. Module test command passes
     2. Source file > 30 lines (catches stubs)
     3. Lint clean
     4. Language-specific checks from CLAUDE.md
       |
6. CODE REVIEWER (code-reviewer skill)
     Reviews implementation for correctness, resource
     management, code quality, and dependencies.
       |
     fix loop: if issues found, dispatch fix agent,
     then re-review until APPROVED (max 3 rounds)
       |
7. INTEGRATE (orchestrator)
     Updates build files (if needed)
     Runs full test suite
     Commits
```

### Why the RED gate matters

If tests pass against stubs, they prove nothing. The
RED gate confirms every test will only pass when real
logic exists. Without it, you get false confidence --
tests that always pass regardless of implementation.

## Skills Reference

Each pipeline stage has a corresponding skill:

| Stage | Skill | Agent Type | Writes |
|-------|-------|------------|--------|
| 1. Tests + stubs | test-writer | programmer | test + stub files |
| 2. Test review | test-reviewer | reviewer | nothing |
| 3. Red gate | (orchestrator) | -- | nothing |
| 4. Implement | implementer | programmer | source files |
| 5. Verify gate | (orchestrator) | -- | nothing |
| 6. Code review | code-reviewer | reviewer | nothing |
| 7. Integrate | (orchestrator) | -- | commit |

Common briefing for all agents: `agent-briefing` skill
(file rules, shell rules, quality bar).

## Orchestrator Rules

The main context is a **pure dispatcher**. It:
- NEVER edits source or test files
- Dispatches agents for all code work
- Runs verify gate checks between stages
- Updates build files after approval
- Runs full integration tests before committing
- Escalates to user after 3 agent rejections

## Agent Workflow

Agents write directly to the working directory. No
branches, no merges.

Test writers write ONLY test files (and minimal type
stubs). Implementers write ONLY source files. Neither
modifies build files. Neither commits.

Agents run the module test command specified in the
project's CLAUDE.md.

## Red Gate

After test review, before implementation:

1. Run module test command
2. ALL tests must FAIL
3. If any test passes, stubs are too complete --
   re-dispatch test-writer to remove real logic
   from stubs

## Verify Gate

After implementation, before code review:

1. Module test command passes
2. Source file > 30 lines (catches stubs)
3. Lint command passes (from CLAUDE.md)
4. Language-specific checks (from CLAUDE.md)

If any check fails: re-dispatch implementer with
specific feedback. Do NOT waste a reviewer dispatch.

## Post-Review Pipeline

After code reviewer approves:
1. Orchestrator updates build files (if needed)
2. Orchestrator runs full test suite
3. Orchestrator commits

## Fix Loops

Both review stages use a fix loop:

1. Reviewer reports NEEDS_FIXES with structured issues
2. Orchestrator dispatches a fix agent (programmer type)
   with the reviewer's feedback
3. Reviewer re-reviews
4. Maximum 3 rounds -- then escalate to user

## Composition with Language Plugins

This pipeline is language-agnostic. Language-specific
behavior comes from:

1. **CLAUDE.md**: test commands, file patterns, lint
   rules, and language-specific checks
2. **Language plugins**: inject corrections into CLAUDE.md
   (e.g. zig-claude-kit adds Zig 0.15.x corrections)
3. **Agent briefing**: directs agents to read CLAUDE.md
   for project-specific context

No coupling exists between this plugin and language
plugins at the code level. CLAUDE.md is the integration
point.
