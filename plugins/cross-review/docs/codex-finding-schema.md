# Codex Finding Schema

Canonical schema block for codex prompts. Both
`codex-review-prompt.md` and `codex-validate-prompt.md`
append this verbatim after their own instructions.

Return findings in this exact schema. Each finding
must fill every field.

    FINDING: <sequential id starting at 1>
    FILE: <path relative to repo root>
    LINES: <start>-<end>
    SEVERITY: <high|medium|low>
    CATEGORY: <trust-boundary|resource-leak|
               race-condition|input-validation|
               error-handling|state-corruption|other>
    ISSUE: <one-line summary>
    DETAIL: <explanation — as long as needed>
    RECOMMENDATION: <concrete fix>

If there are no material findings, return:

    NO_FINDINGS: Code review found no material issues.

<!-- keep in sync with agents/reviewer.md and
     agents/validator.md -->
