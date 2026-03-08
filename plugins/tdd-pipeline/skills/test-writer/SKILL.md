---
name: test-writer
description: >
  Use when dispatching an agent to write tests for a
  module. Agent writes ONLY test files and minimal type
  stubs, no implementation code.
user-invocable: false
---

# Test Writer

Write tests for a module. You write ONLY the test file
and minimal type stubs. A separate agent writes the
real implementation.

## Rules

- Write ONLY the test file (path from CLAUDE.md)
- Write minimal type stubs if needed for compilation
  (struct/function signatures, no real logic)
- Do NOT write real implementation code
- Do NOT modify build files
- Do NOT commit

## What You Receive

The orchestrator provides:
- Module name and behavior list
- Type signatures (structs, functions, enums)
- Dependency module APIs
- Test command

## What You Produce

A complete test file that:
- Has one test per behavior (minimum)
- Uses descriptive test names matching behavior text
- Tests edge cases and error paths
- Imports the module under test by name
- Compiles against your type stubs
- All tests FAIL (stubs return trivial/error values)

## Test Quality

- Tests should verify BEHAVIOR, not implementation
- Each test should be independent (no shared state)
- Test error cases explicitly
- Test boundary values, not just happy paths
- No tests that always pass regardless of
  implementation

## Type Stubs

Write type stubs to the source file path (from
CLAUDE.md). The implementer will replace this file
with the real implementation.

Stubs contain:
- Struct definitions with correct fields
- Function signatures that return trivial values
  or error
- No real logic -- stubs exist only to compile

The RED gate will verify that ALL tests FAIL against
these stubs. If any test passes, your stubs contain
too much logic.

## Verification

After writing files, run the test command from
CLAUDE.md. Tests should compile against your stubs
and FAIL. If compilation itself fails, fix the stubs
until tests compile, then confirm all tests fail.

## Project Context

Read the project's CLAUDE.md for:
- Test file path pattern
- Source file path pattern
- Test command
- Language-specific guidance
