# REQ-DATA-003: Results Visualization

## Status: MISSING
## Priority: MEDIUM
## Phase: 3

## Requirement

rtmx-bench shall generate publication-quality visualizations from
experiment results, suitable for blog posts, papers, and README
embedding.

## Rationale

Numbers in a CSV are for machines. Humans understand charts. The
benchmark needs visualizations that tell the story clearly: does RTMX
save tokens? How does the saving compound across tasks? How does
knowledge entropy correlate with token cost? These visualizations
are also the primary marketing artifact for RTMX -- "here's the data"
is more compelling than "trust us."

## Acceptance Criteria

1. `analysis/plot.py` generates the following charts from
   `results/summary.csv`:
   a. **Token comparison bar chart**: mean total_tokens per condition
      per experiment, with 95% CI error bars
   b. **Token breakdown stacked bar**: planning_tokens vs
      execution_tokens vs rtmx_tokens per condition
   c. **Amortization curve**: cumulative tokens per completed task
      over sequential tasks (for multi-task experiments), one line
      per condition
   d. **Completion rate comparison**: bar chart of PASS rates per
      condition per experiment
   e. **Entropy correlation scatter**: knowledge_entropy (x) vs
      total_tokens (y) across all experiments, with regression line
      and R-squared
   f. **Tool call distribution**: for treatment condition, pie or
      bar chart of RTMX tokens by tool name
2. Charts are saved as PNG (300 DPI) and SVG to `results/charts/`
3. Charts use a consistent, colorblind-safe palette
4. Charts include axis labels, titles, and legend
5. `make charts` generates all visualizations from current data
6. Charts degrade gracefully: if an experiment has no data, that
   chart is skipped with a warning, not a crash

## Dependencies

- REQ-HARNESS-005: Statistical analysis (provides computed metrics)
- REQ-DATA-001: Ledger format (reads the CSV)
- REQ-ENTROPY-005: Composite score (provides entropy data for
  correlation chart)

## Files to Create

- `analysis/plot.py` -- visualization generation
- `analysis/style.py` -- shared chart styling (palette, fonts)
