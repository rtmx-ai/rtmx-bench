.PHONY: setup test test-harness test-entropy test-data run-all analyze charts validate clean

# Default model for experiments
MODEL ?= claude-sonnet-4-20250514
RUNS ?= 5

setup:
	@echo "=== Installing dependencies ==="
	@command -v python3 >/dev/null || (echo "ERROR: python3 required" && exit 1)
	@command -v git >/dev/null || (echo "ERROR: git required" && exit 1)
	@command -v claude >/dev/null || (echo "WARNING: claude CLI not found -- experiments will not run")
	@pip3 install -q -r analysis/requirements.txt 2>/dev/null || echo "WARNING: analysis deps not installed (pip3 install -r analysis/requirements.txt)"
	@chmod +x bench.sh entropy/scan.sh lib/*.sh tests/*.sh 2>/dev/null || true
	@echo "=== Setup complete ==="

test: test-harness test-entropy test-staleness test-tokens test-analysis test-entropy-advanced

test-harness:
	@bash tests/test_harness.sh

test-entropy:
	@bash tests/test_entropy.sh

test-staleness:
	@bash tests/test_staleness.sh

test-tokens:
	@bash tests/test_tokens.sh

test-analysis:
	@python3 tests/test_analysis.py

test-entropy-advanced:
	@python3 tests/test_entropy_advanced.py

test-data:
	@bash tests/test_data.sh

validate:
	@for exp in experiments/*.yaml; do \
		name=$$(basename "$$exp" .yaml); \
		./bench.sh validate "$$name"; \
	done

run-all:
	@for exp in experiments/*.yaml; do \
		name=$$(basename "$$exp" .yaml); \
		echo "--- Running $$name (control) ---"; \
		./bench.sh run "$$name" --condition control --runs $(RUNS) --model $(MODEL); \
		echo "--- Running $$name (treatment) ---"; \
		./bench.sh run "$$name" --condition treatment --runs $(RUNS) --model $(MODEL); \
	done

analyze:
	@python3 analysis/compare.py

charts:
	@python3 analysis/plot.py

entropy:
	@bash entropy/scan.sh report $(REPO)

clean:
	rm -rf results/raw/* results/charts/*
	rm -f results/summary.csv
