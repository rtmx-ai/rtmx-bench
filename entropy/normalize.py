#!/usr/bin/env python3
"""Dimension normalization and weighting for composite entropy score.

REQ-ENTROPY-005: Composite entropy score normalizes and weights all
dimensions into a single metric.

Normalization baselines:
  - scatter:      1 file = 0.0, 20+ files = 1.0 (linear)
  - staleness:    0% stale = 0.0, 100% stale = 1.0 (direct)
  - navigability: 1 read = 0.0, 10+ reads = 1.0 (linear)
  - duplication:  0% = 0.0, 50%+ = 1.0 (linear, capped)

Default weights (sum to 1.0):
  scatter=0.30, staleness=0.30, navigability=0.25, duplication=0.15
"""

import argparse
import json
import sys

# Normalization parameters
BASELINES = {
    "scatter": {"min": 1, "max": 20},
    "staleness": {"min": 0.0, "max": 1.0},
    "navigability": {"min": 1, "max": 10},
    "duplication": {"min": 0.0, "max": 0.5},
}

DEFAULT_WEIGHTS = {
    "scatter": 0.30,
    "staleness": 0.30,
    "navigability": 0.25,
    "duplication": 0.15,
}


def normalize(value: float, dim: str) -> float:
    """Normalize a dimension value to [0, 1]."""
    baseline = BASELINES[dim]
    lo, hi = baseline["min"], baseline["max"]
    if value <= lo:
        return 0.0
    if value >= hi:
        return 1.0
    return (value - lo) / (hi - lo)


def compute_composite(dimensions: dict[str, float | None]) -> dict:
    """Compute composite entropy score from available dimensions.

    Args:
        dimensions: dict mapping dimension name to raw value (or None if unavailable)

    Returns:
        dict with entropy_score and per-dimension breakdown
    """
    available = {k: v for k, v in dimensions.items() if v is not None}
    excluded = {k for k, v in dimensions.items() if v is None}

    # Re-normalize weights for available dimensions
    total_weight = sum(DEFAULT_WEIGHTS[k] for k in available)
    if total_weight == 0:
        weights = {k: 0 for k in available}
    else:
        weights = {k: DEFAULT_WEIGHTS[k] / total_weight for k in available}

    # Normalize and weight
    result_dimensions = []
    weighted_sum = 0.0

    for dim in ["scatter", "staleness", "navigability", "duplication"]:
        raw = dimensions.get(dim)
        included = raw is not None
        norm = normalize(raw, dim) if included else 0.0
        weight = weights.get(dim, 0.0) if included else 0.0
        weighted_sum += norm * weight

        result_dimensions.append({
            "name": dim,
            "raw": f"{raw}" if raw is not None else "N/A",
            "normalized": round(norm, 3),
            "weight": round(weight, 3),
            "included": included,
        })

    # Scale to 0-10
    entropy_score = round(weighted_sum * 10, 1)

    return {
        "entropy_score": entropy_score,
        "dimensions": result_dimensions,
        "dimensions_included": len(available),
        "dimensions_excluded": list(excluded),
    }


def main():
    parser = argparse.ArgumentParser(description="Compute composite entropy score")
    parser.add_argument("--scatter", type=str, required=True)
    parser.add_argument("--staleness", type=str, required=True)
    parser.add_argument("--navigability", type=str, default="null")
    parser.add_argument("--duplication", type=str, default="null")
    args = parser.parse_args()

    def parse_val(s: str) -> float | None:
        if s in ("null", "None", ""):
            return None
        return float(s)

    dimensions = {
        "scatter": parse_val(args.scatter),
        "staleness": parse_val(args.staleness),
        "navigability": parse_val(args.navigability),
        "duplication": parse_val(args.duplication),
    }

    result = compute_composite(dimensions)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
