# REQ-DATA-004: Analysis Idempotency

## Status: MISSING
## Priority: MEDIUM
## Phase: 3

## Requirement

rtmx-bench analysis shall be idempotent: re-running analysis on
unchanged inputs produces no new computation or token consumption.

## Rationale

As the benchmark scales to multiple experiments with many runs, the
analysis step should not redundantly reprocess unchanged data. Each
analysis run re-reads the full ledger and recomputes all statistics.
With expensive operations (entropy correlation, bootstrap CI), this
wastes time. More importantly, if analysis triggers any token-consuming
operations (navigability probes), idempotency prevents accidental cost.

## Acceptance Criteria

1. compare.py computes a SHA-256 hash of its inputs (ledger content
   + script source) and stores it in analysis.json metadata
2. On subsequent runs, if the input hash matches the cached hash,
   print "Analysis unchanged, skipping." and exit 0
3. A `--force` flag bypasses the cache and recomputes
4. plot.py checks whether its inputs (ledger + analysis.json) are
   newer than its outputs (chart files); skips if charts are current
5. plot.py also supports `--force` to regenerate all charts
6. The cache key includes the analysis script source so code changes
   invalidate the cache automatically

## Dependencies

- REQ-HARNESS-005: Statistical analysis (provides the analysis to cache)

## Files to Modify

- `analysis/compare.py` -- add input hashing, cache check, --force flag
- `analysis/plot.py` -- add input freshness check, --force flag
