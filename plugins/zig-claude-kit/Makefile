.PHONY: help eval eval-model compile-test audit audit-0.15 audit-0.16 clean

help: ## Show available targets
	@grep -E '^[a-zA-Z_.0-9-]+:.*##' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*## "}; {printf "  %-18s %s\n", $$1, $$2}'

# Default Zig target for evals
TARGET ?= 0.16

# --- Model Evaluation ---

eval: ## Blind-test default models (TARGET=0.16 or 0.15)
	uv run scripts/zig-knowledge-eval.py --target $(TARGET)

eval-model: ## Blind-test one model (MODEL=claude-haiku-4-5 TARGET=0.16)
	uv run scripts/zig-knowledge-eval.py --target $(TARGET) --models $(MODEL)

compile-test: ## Compile-test saved probes (MODEL=... TARGET=0.16)
	./scripts/zig-knowledge-test.sh probes/$(TARGET)/$(MODEL)

# --- Compiler Probes ---

audit: ## Validate breaking-change claims (auto-detects Zig version)
	@if zig version 2>/dev/null | grep -q '^0\.15'; then \
		./scripts/zig-knowledge-audit-0.15.sh; \
	else \
		./scripts/zig-knowledge-audit-0.16.sh; \
	fi

audit-0.15: ## Validate 0.15.x claims (requires Zig 0.15.x)
	./scripts/zig-knowledge-audit-0.15.sh

audit-0.16: ## Validate 0.16 claims (requires Zig 0.16)
	./scripts/zig-knowledge-audit-0.16.sh

# --- Cleanup ---

clean: ## Remove all generated probe files
	rm -rf probes/
