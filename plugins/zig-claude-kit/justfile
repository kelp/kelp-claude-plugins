# Default recipe — list all available recipes
default:
    @just --list

# --- Model Evaluation ---

# Blind-test all default models (sonnet + opus 4.6)
eval:
    uv run scripts/zig-knowledge-eval.py

# Blind-test a specific model
eval-model model:
    uv run scripts/zig-knowledge-eval.py --models {{model}}

# Generate code only, skip compilation
eval-generate *models:
    uv run scripts/zig-knowledge-eval.py --skip-compile {{ if models == "" { "" } else { "--models " + models } }}

# Compile-test previously generated probes for a model
compile-test model:
    ./scripts/zig-knowledge-test.sh probes/{{model}}

# --- Compiler Probes ---

# Run compiler probes to validate breaking change claims
audit:
    ./scripts/zig-knowledge-audit.sh

# --- Cleanup ---

# Remove all generated probe files
clean:
    rm -rf probes/
