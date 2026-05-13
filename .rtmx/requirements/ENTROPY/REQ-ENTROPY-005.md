# REQ-ENTROPY-005: Composite Entropy Score

## Status: MISSING
## Priority: HIGH
## Phase: 3

## Requirement

rtmx-bench shall compute a single composite knowledge entropy score
from the individual dimension scores, providing a summary metric for
project knowledge organization quality.

## Rationale

Individual dimension scores (scatter, staleness, navigability,
duplication) are useful for diagnosis but unwieldy for comparison.
A composite score enables statements like "Project A has entropy 7.2,
Project B has entropy 3.1" and correlation analysis against agent
token consumption.

The composite must be interpretable: higher entropy means more
disorganized knowledge, which we hypothesize correlates with higher
agent token cost per completed task.

## Acceptance Criteria

1. `entropy score <repo_path>` computes all available dimension
   scores and produces a composite:
   entropy = w1*scatter_norm + w2*staleness_norm + w3*navigability_norm
             + w4*duplication_norm
   where each dimension is normalized to [0, 1] and weights sum to 1
2. Default weights: scatter=0.3, staleness=0.3, navigability=0.25,
   duplication=0.15 (scatter and staleness are cheaply computable and
   most actionable; navigability requires probe sessions; duplication
   requires content analysis)
3. If a dimension is unavailable (e.g., navigability probe not run),
   the composite is computed from available dimensions with weights
   re-normalized. Reports which dimensions were included.
4. Normalization baselines:
   - scatter: 1 file = 0.0, 20+ files = 1.0 (linear interpolation)
   - staleness: 0% stale = 0.0, 100% stale = 1.0
   - navigability: 1 read = 0.0, 10+ reads = 1.0
   - duplication: 0% = 0.0, 50%+ = 1.0
5. Composite score is a float in [0.0, 10.0] (entropy * 10 for
   readability)
6. Outputs full report: composite score, per-dimension raw and
   normalized scores, interpretation guide
7. Outputs structured JSON: `{"entropy_score": N, "dimensions": {...}}`

## Dependencies

- REQ-ENTROPY-001: Scatter score
- REQ-ENTROPY-002: Staleness score
- REQ-ENTROPY-003: Navigability score (optional at runtime)
- REQ-ENTROPY-004: Duplication score (optional at runtime)

## Files to Create

- `entropy/score.sh` -- composite score computation
- `entropy/normalize.py` -- normalization and weighting logic
