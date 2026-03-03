.PHONY: help eval eval-model compile-test audit clean

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*## "}; {printf "  %-16s %s\n", $$1, $$2}'

# --- Model Evaluation ---

eval: ## Blind-test all default models (sonnet + opus 4.6)
	uv run scripts/zig-knowledge-eval.py

eval-model: ## Blind-test a specific model (MODEL=claude-haiku-4-5)
	uv run scripts/zig-knowledge-eval.py --models $(MODEL)

compile-test: ## Compile-test saved probes (MODEL=claude-sonnet-4-6)
	./scripts/zig-knowledge-test.sh probes/$(MODEL)

# --- Compiler Probes ---

audit: ## Validate breaking change claims against current Zig
	./scripts/zig-knowledge-audit.sh

# --- Cleanup ---

clean: ## Remove all generated probe files
	rm -rf probes/
