## Cross-Review Configuration

### Codex Script (optional)
By default, cross-review looks for the codex
companion script at
`$HOME/.claude/plugins/marketplaces/openai-codex/plugins/codex/scripts/codex-companion.mjs`.
Only set `codex-script:` below if your codex install
lives somewhere else. For security, the resolved
path must be under `$HOME/.claude/plugins/` — paths
outside that prefix are rejected.

# codex-script: $HOME/.claude/plugins/marketplaces/openai-codex/plugins/codex/scripts/codex-companion.mjs

### Review Focus (optional)
Customize what cross-review prioritizes for this
project. Uncomment the line below and replace the
example with your own focus, or leave commented to
use defaults.

# review-focus: auth boundaries, database migrations, API compatibility
