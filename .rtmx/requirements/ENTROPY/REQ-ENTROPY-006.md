# REQ-ENTROPY-006: Entropy Pipeline Integration

## Status: MISSING
## Priority: HIGH
## Phase: 2

## Requirement

rtmx-bench shall compute the knowledge entropy score of each agent's
output after every experiment run and record it in the ledger for
correlation analysis against token consumption.

## Rationale

The entropy scanner (REQ-ENTROPY-001 through 005) is fully implemented
but never called during benchmark runs. The knowledge_entropy column
in summary.csv is always empty. Without this data, we cannot test the
central thesis: that RTMX reduces knowledge entropy, and that lower
entropy correlates with lower token consumption. This requirement
closes the loop between measurement and analysis.

## Acceptance Criteria

1. After each agent session completes and before the workdir is
   archived, run `entropy/score.sh scan` on the working directory
2. Write the composite entropy score (float, 0-10) to the
   knowledge_entropy column in the ledger row
3. If scoring fails (e.g., empty workdir), leave knowledge_entropy
   empty rather than blocking the run
4. Initialize a git repository in the workdir before scoring if one
   does not exist (staleness scoring requires git history)
5. analysis/compare.py computes Spearman correlation between
   knowledge_entropy and total_tokens when >= 3 data points exist
6. analysis/plot.py generates the entropy_correlation chart when
   data is available (currently skipped with "insufficient data")

## Dependencies

- REQ-ENTROPY-005: Composite entropy score (provides the scorer)
- REQ-HARNESS-001: Experiment runner (provides the execution hook)

## Files to Modify

- `bench.sh` -- replace hardcoded empty string with score.sh call
- `analysis/compare.py` -- add entropy correlation analysis
