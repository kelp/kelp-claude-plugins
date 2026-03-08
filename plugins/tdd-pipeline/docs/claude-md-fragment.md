## TDD Pipeline Configuration

### Test Command
`<TEST_COMMAND e.g. pytest tests/test_{module}.py>`

### Source Layout
- Source: `<SOURCE_PATTERN e.g. src/{module}.py>`
- Tests: `<TEST_PATTERN e.g. tests/test_{module}.py>`

### Build Integration
- After approval: <what to update, if anything>
- Full test: `<FULL_TEST_COMMAND>`
- Lint: `<LINT_COMMAND>`

### Verify Gate Checks
- Tests pass: `<MODULE_TEST_COMMAND>`
- No stubs: source file > 30 lines (adjust threshold
  for your language)
- Lint clean: `<LINT_COMMAND>`
- Language checks: <optional, e.g. grep for anti-patterns>

### Language-Specific Agent Context
<Optional: language corrections, plugin skill references>
