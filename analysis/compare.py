#!/usr/bin/env python3
"""Statistical analysis for rtmx-bench experiments.

REQ-HARNESS-005: Statistical analysis computes significance tests and
amortization curves from experiment results.
"""

import json
import sys
from pathlib import Path

import pandas as pd
from scipy import stats


def load_ledger(path: str = "results/summary.csv") -> pd.DataFrame:
    """Load and validate the experiment ledger."""
    df = pd.read_csv(path)
    required = [
        "experiment", "condition", "total_tokens", "outcome",
        "input_tokens", "output_tokens", "rtmx_tokens",
        "planning_tokens", "execution_tokens", "turns", "backtracks",
    ]
    missing = [c for c in required if c not in df.columns]
    if missing:
        print(f"ERROR: Missing columns: {missing}", file=sys.stderr)
        sys.exit(1)
    return df


def filter_pass(df: pd.DataFrame) -> pd.DataFrame:
    """Filter to PASS outcomes only, excluding ERROR runs."""
    return df[df["outcome"] == "PASS"]


def filter_no_errors(df: pd.DataFrame) -> pd.DataFrame:
    """Exclude ERROR outcomes (infrastructure failures)."""
    return df[df["outcome"] != "ERROR"]


def compute_stats(series: pd.Series) -> dict:
    """Compute summary statistics for a numeric series."""
    if len(series) == 0:
        return {"mean": 0, "median": 0, "std": 0, "n": 0}
    return {
        "mean": round(float(series.mean()), 1),
        "median": round(float(series.median()), 1),
        "std": round(float(series.std()), 1),
        "n": int(len(series)),
    }


def bootstrap_ci(a: pd.Series, b: pd.Series, n_boot: int = 10000,
                 alpha: float = 0.05) -> dict:
    """Bootstrap 95% CI for the ratio of means (a/b)."""
    import numpy as np

    if len(a) == 0 or len(b) == 0:
        return {"ratio": 0, "ci_lower": 0, "ci_upper": 0}

    rng = np.random.default_rng(42)
    ratios = []
    for _ in range(n_boot):
        a_sample = rng.choice(a.values, size=len(a), replace=True)
        b_sample = rng.choice(b.values, size=len(b), replace=True)
        b_mean = b_sample.mean()
        if b_mean > 0:
            ratios.append(a_sample.mean() / b_mean)

    if not ratios:
        return {"ratio": 0, "ci_lower": 0, "ci_upper": 0}

    ratios = sorted(ratios)
    lower_idx = int(alpha / 2 * len(ratios))
    upper_idx = int((1 - alpha / 2) * len(ratios))

    return {
        "ratio": round(float(a.mean() / b.mean()), 3),
        "ci_lower": round(ratios[lower_idx], 3),
        "ci_upper": round(ratios[upper_idx], 3),
    }


def analyze_experiment(df: pd.DataFrame, experiment: str) -> dict:
    """Analyze a single experiment's results."""
    exp_df = df[df["experiment"] == experiment]
    exp_clean = filter_no_errors(exp_df)
    exp_pass = filter_pass(exp_df)

    control = exp_clean[exp_clean["condition"] == "control"]
    treatment = exp_clean[exp_clean["condition"] == "treatment"]
    control_pass = exp_pass[exp_pass["condition"] == "control"]
    treatment_pass = exp_pass[exp_pass["condition"] == "treatment"]

    result = {
        "experiment": experiment,
        "runs": {
            "control": int(len(control)),
            "treatment": int(len(treatment)),
        },
        "completion_rate": {
            "control": round(len(control_pass) / max(len(control), 1), 3),
            "treatment": round(len(treatment_pass) / max(len(treatment), 1), 3),
        },
        "total_tokens": {
            "control": compute_stats(control_pass["total_tokens"]),
            "treatment": compute_stats(treatment_pass["total_tokens"]),
        },
        "turns": {
            "control": compute_stats(control_pass["turns"]),
            "treatment": compute_stats(treatment_pass["turns"]),
        },
        "backtracks": {
            "control": compute_stats(control_pass["backtracks"]),
            "treatment": compute_stats(treatment_pass["backtracks"]),
        },
    }

    # Token breakdown for treatment
    if len(treatment_pass) > 0:
        result["treatment_breakdown"] = {
            "rtmx_tokens": compute_stats(treatment_pass["rtmx_tokens"]),
            "planning_tokens": compute_stats(treatment_pass["planning_tokens"]),
            "execution_tokens": compute_stats(treatment_pass["execution_tokens"]),
        }

    # Token efficiency ratio with bootstrap CI
    if len(control_pass) > 0 and len(treatment_pass) > 0:
        result["token_efficiency"] = bootstrap_ci(
            control_pass["total_tokens"],
            treatment_pass["total_tokens"],
        )

        # Mann-Whitney U test
        u_stat, p_value = stats.mannwhitneyu(
            control_pass["total_tokens"],
            treatment_pass["total_tokens"],
            alternative="two-sided",
        )
        result["mann_whitney"] = {
            "u_statistic": round(float(u_stat), 1),
            "p_value": round(float(p_value), 4),
            "significant": p_value < 0.05,
        }

    # Backtrack rate
    for cond in ["control", "treatment"]:
        cond_pass = control_pass if cond == "control" else treatment_pass
        if len(cond_pass) > 0:
            total_turns = cond_pass["turns"].sum()
            total_backtracks = cond_pass["backtracks"].sum()
            if total_turns > 0:
                result[f"backtrack_rate_{cond}"] = round(
                    float(total_backtracks / total_turns), 3
                )

    # Warn if insufficient runs
    for cond in ["control", "treatment"]:
        n = result["runs"][cond]
        if n < 5:
            result.setdefault("warnings", []).append(
                f"Insufficient runs for {cond}: {n} < 5 "
                "(results may not be statistically significant)"
            )

    return result


def print_report(results: list[dict]):
    """Print human-readable analysis report."""
    for r in results:
        print(f"{'=' * 60}")
        print(f"Experiment: {r['experiment']}")
        print(f"{'=' * 60}")
        print()

        # Runs and completion
        print(f"  Runs:            control={r['runs']['control']}, treatment={r['runs']['treatment']}")
        print(f"  Completion rate: control={r['completion_rate']['control']:.0%}, treatment={r['completion_rate']['treatment']:.0%}")
        print()

        # Token summary
        c = r["total_tokens"]["control"]
        t = r["total_tokens"]["treatment"]
        print("  Total tokens (PASS only):")
        print(f"    Control:   mean={c['mean']:.0f}  median={c['median']:.0f}  std={c['std']:.0f}  n={c['n']}")
        print(f"    Treatment: mean={t['mean']:.0f}  median={t['median']:.0f}  std={t['std']:.0f}  n={t['n']}")
        print()

        # Efficiency ratio
        if "token_efficiency" in r:
            te = r["token_efficiency"]
            direction = "RTMX saves tokens" if te["ratio"] > 1.0 else "RTMX adds overhead" if te["ratio"] < 1.0 else "neutral"
            print(f"  Token efficiency ratio: {te['ratio']:.3f} ({direction})")
            print(f"    95% CI: [{te['ci_lower']:.3f}, {te['ci_upper']:.3f}]")
            print()

        # Significance
        if "mann_whitney" in r:
            mw = r["mann_whitney"]
            sig = "YES" if mw["significant"] else "NO"
            print(f"  Mann-Whitney U: U={mw['u_statistic']:.0f}, p={mw['p_value']:.4f} (significant: {sig})")
            print()

        # Treatment breakdown
        if "treatment_breakdown" in r:
            tb = r["treatment_breakdown"]
            print("  Treatment token breakdown:")
            print(f"    RTMX tokens:      mean={tb['rtmx_tokens']['mean']:.0f}")
            print(f"    Planning tokens:  mean={tb['planning_tokens']['mean']:.0f}")
            print(f"    Execution tokens: mean={tb['execution_tokens']['mean']:.0f}")
            print()

        # Backtrack rates
        for cond in ["control", "treatment"]:
            key = f"backtrack_rate_{cond}"
            if key in r:
                print(f"  Backtrack rate ({cond}): {r[key]:.1%}")

        # Warnings
        if "warnings" in r:
            print()
            for w in r["warnings"]:
                print(f"  WARNING: {w}")

        print()


def main():
    ledger_path = sys.argv[1] if len(sys.argv) > 1 else "results/summary.csv"

    if not Path(ledger_path).exists():
        print(f"ERROR: Ledger not found: {ledger_path}", file=sys.stderr)
        print("Run experiments first, then analyze.", file=sys.stderr)
        sys.exit(1)

    df = load_ledger(ledger_path)

    if len(df) == 0:
        print("No experiment data to analyze.")
        sys.exit(0)

    experiments = df["experiment"].unique()
    results = [analyze_experiment(df, exp) for exp in experiments]

    # Human-readable report
    print_report(results)

    # Machine-readable JSON
    output_path = Path(ledger_path).parent / "analysis.json"
    output_path.write_text(json.dumps(results, indent=2))
    print(f"Analysis written to {output_path}")


if __name__ == "__main__":
    main()
