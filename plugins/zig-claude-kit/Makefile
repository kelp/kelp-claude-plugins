.PHONY: help eval eval-015 eval-016 eval-model compile-test \
        audit audit-015 audit-016 audit-all clean

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*## "}; {printf "  %-16s %s\n", $$1, $$2}'

# --- Model Evaluation ---

# Default eval is 0.15.x against the `zig` on PATH (preserves the
# behavior the README's eval-results table was generated with).
eval: ## Blind-test all default models against Zig 0.15.x
	uv run scripts/zig-knowledge-eval.py --version 0.15

eval-015: ## Blind-test against Zig 0.15.x (alias for `eval`)
	uv run scripts/zig-knowledge-eval.py --version 0.15

eval-016: ## Blind-test against Zig 0.16.x (uses ZIG=$$(mise where zig@0.16.0)/bin/zig if ZIG unset)
	@ZIG=$${ZIG:-$$(mise where zig@0.16.0 2>/dev/null)/bin/zig}; \
	if [ ! -x "$$ZIG" ]; then \
	    echo "Could not locate Zig 0.16.0. Install it (mise install zig@0.16.0)"; \
	    echo "or pass ZIG=/path/to/zig explicitly."; \
	    exit 1; \
	fi; \
	uv run scripts/zig-knowledge-eval.py --version 0.16 --zig "$$ZIG"

eval-model: ## Blind-test a specific model (MODEL=claude-haiku-4-5)
	uv run scripts/zig-knowledge-eval.py --models $(MODEL)

compile-test: ## Compile-test saved probes (MODEL=claude-sonnet-4-6, VERSION=0.15)
	./scripts/zig-knowledge-test.sh probes/$(MODEL)-$(or $(VERSION),0.15)

# --- Compiler Probes ---

audit: audit-015 ## Alias for audit-015 (default)

audit-015: ## Validate 0.15 breaking-change claims against zig on PATH
	./scripts/zig-knowledge-audit.sh --version 0.15

audit-016: ## Validate 0.16 claims against Zig 0.16.0 (uses ZIG=$$(mise where zig@0.16.0)/bin/zig if ZIG unset)
	@ZIG=$${ZIG:-$$(mise where zig@0.16.0 2>/dev/null)/bin/zig}; \
	if [ ! -x "$$ZIG" ]; then \
	    echo "Could not locate Zig 0.16.0. Install it (mise install zig@0.16.0)"; \
	    echo "or pass ZIG=/path/to/zig explicitly."; \
	    exit 1; \
	fi; \
	ZIG="$$ZIG" ./scripts/zig-knowledge-audit.sh --version 0.16

audit-all: ## Run audit-015 and audit-016 back-to-back; nonzero if either fails
	@set -e; \
	echo ""; echo "==> audit-015"; $(MAKE) --no-print-directory audit-015; \
	echo ""; echo "==> audit-016"; $(MAKE) --no-print-directory audit-016

# --- Cleanup ---

clean: ## Remove all generated probe files
	rm -rf probes/
