# REQ-HARNESS-005: Statistical Analysis

## Status: MISSING
## Priority: HIGH
## Phase: 2

## Requirement

rtmx-bench shall provide analysis tooling that computes summary
statistics, significance tests, and the planning amortization curve
from experiment results.

## Rationale

Single-run comparisons are anecdotal. Model output is stochastic --
the same prompt can produce sessions ranging from 5,000 to 50,000
tokens. Statistical analysis across N runs per condition reveals
whether observed differences are signal or noise. The amortization
curve tests the specific hypothesis that RTMX planning cost is
front-loaded and execution savings compound across tasks.

## Acceptance Criteria

1. `analysis/compare.py` reads `results/summary.csv` and computes
   per-condition, per-experiment:
   - Mean, median, std dev of total_tokens for PASS outcomes only
   - Mean, median, std dev of turns for PASS outcomes only
   - Completion rate (PASS / total runs)
   - Backtrack rate (backtracks / turns)
2. Computes token efficiency ratio:
   mean_tokens(control) / mean_tokens(treatment)
   with 95% confidence interval via bootstrap
3. Runs Mann-Whitney U test (non-parametric, no normality assumption)
   on total_tokens between conditions; reports p-value
4. Computes planning amortization curve: for multi-task experiments,
   plots cumulative tokens per completed task as task count increases,
   showing whether treatment cost per task decreases over time
5. Outputs results as both human-readable text (stdout) and
   machine-readable JSON (`results/analysis.json`)
6. Warns if N < 5 per condition ("insufficient runs for statistical
   significance")
7. Filters out ERROR outcomes (infrastructure failures) from analysis

## Dependencies

- REQ-HARNESS-001: Experiment runner (produces the data)
- REQ-HARNESS-002: Token accounting (provides token breakdowns)
- REQ-HARNESS-004: Outcome verification (provides pass/fail classification)

## Files to Create

- `analysis/compare.py` -- statistical analysis
- `analysis/requirements.txt` -- Python dependencies (scipy, pandas)
