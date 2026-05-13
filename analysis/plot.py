#!/usr/bin/env python3
"""Visualization generation for rtmx-bench experiments.

REQ-DATA-003: Publication-quality charts generated from experiment results.
"""

import json
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")  # Non-interactive backend
import matplotlib.pyplot as plt
import pandas as pd
import numpy as np

from style import COLORS, DPI, apply_style


def load_data(ledger_path: str = "results/summary.csv") -> pd.DataFrame:
    """Load experiment ledger."""
    return pd.read_csv(ledger_path)


def chart_token_comparison(df: pd.DataFrame, output_dir: Path):
    """Bar chart: mean total_tokens per condition per experiment with CI."""
    pass_df = df[df["outcome"] == "PASS"]
    experiments = pass_df["experiment"].unique()

    if len(experiments) == 0:
        print("  [SKIP] token_comparison -- no PASS data")
        return

    fig, ax = plt.subplots(figsize=(8, 5))
    x = np.arange(len(experiments))
    width = 0.35

    for i, condition in enumerate(["control", "treatment"]):
        means = []
        cis = []
        for exp in experiments:
            data = pass_df[(pass_df["experiment"] == exp) & (pass_df["condition"] == condition)]
            means.append(data["total_tokens"].mean() if len(data) > 0 else 0)
            cis.append(data["total_tokens"].std() * 1.96 / max(np.sqrt(len(data)), 1) if len(data) > 1 else 0)

        color = COLORS[condition]
        offset = -width / 2 + i * width
        ax.bar(x + offset, means, width, yerr=cis, label=condition.capitalize(),
               color=color, capsize=4, alpha=0.85)

    ax.set_xticks(x)
    ax.set_xticklabels(experiments, rotation=15)
    apply_style(ax, "Token Consumption: Control vs Treatment",
                "Experiment", "Total Tokens (PASS only)")
    ax.legend()
    fig.tight_layout()

    for fmt in ["png", "svg"]:
        fig.savefig(output_dir / f"token_comparison.{fmt}", dpi=DPI)
    plt.close(fig)
    print("  [OK] token_comparison")


def chart_token_breakdown(df: pd.DataFrame, output_dir: Path):
    """Stacked bar: planning vs execution vs rtmx tokens per condition."""
    pass_df = df[df["outcome"] == "PASS"]
    experiments = pass_df["experiment"].unique()

    if len(experiments) == 0:
        print("  [SKIP] token_breakdown -- no PASS data")
        return

    fig, axes = plt.subplots(1, len(experiments), figsize=(6 * len(experiments), 5),
                             squeeze=False)

    for idx, exp in enumerate(experiments):
        ax = axes[0, idx]
        for i, condition in enumerate(["control", "treatment"]):
            data = pass_df[(pass_df["experiment"] == exp) & (pass_df["condition"] == condition)]
            if len(data) == 0:
                continue

            planning = data["planning_tokens"].mean()
            execution = data["execution_tokens"].mean()
            rtmx = data["rtmx_tokens"].mean()

            bottom = 0
            for val, label, color in [
                (rtmx, "RTMX", COLORS["rtmx"]),
                (planning - rtmx, "Planning", COLORS["planning"]),
                (execution, "Execution", COLORS["execution"]),
            ]:
                if val > 0:
                    ax.bar(condition.capitalize(), val, bottom=bottom,
                           label=label if i == 0 else "", color=color, alpha=0.85)
                    bottom += val

        apply_style(ax, f"Token Breakdown: {exp}", "", "Tokens")
        if idx == 0:
            ax.legend()

    fig.tight_layout()
    for fmt in ["png", "svg"]:
        fig.savefig(output_dir / f"token_breakdown.{fmt}", dpi=DPI)
    plt.close(fig)
    print("  [OK] token_breakdown")


def chart_completion_rate(df: pd.DataFrame, output_dir: Path):
    """Bar chart: PASS rates per condition per experiment."""
    no_error = df[df["outcome"] != "ERROR"]
    experiments = no_error["experiment"].unique()

    if len(experiments) == 0:
        print("  [SKIP] completion_rate -- no data")
        return

    fig, ax = plt.subplots(figsize=(8, 5))
    x = np.arange(len(experiments))
    width = 0.35

    for i, condition in enumerate(["control", "treatment"]):
        rates = []
        for exp in experiments:
            data = no_error[(no_error["experiment"] == exp) & (no_error["condition"] == condition)]
            if len(data) == 0:
                rates.append(0)
            else:
                rates.append((data["outcome"] == "PASS").mean())

        color = COLORS[condition]
        offset = -width / 2 + i * width
        ax.bar(x + offset, [r * 100 for r in rates], width,
               label=condition.capitalize(), color=color, alpha=0.85)

    ax.set_xticks(x)
    ax.set_xticklabels(experiments, rotation=15)
    ax.set_ylim(0, 110)
    apply_style(ax, "Task Completion Rate", "Experiment", "Completion Rate (%)")
    ax.legend()
    fig.tight_layout()

    for fmt in ["png", "svg"]:
        fig.savefig(output_dir / f"completion_rate.{fmt}", dpi=DPI)
    plt.close(fig)
    print("  [OK] completion_rate")


def chart_entropy_correlation(df: pd.DataFrame, output_dir: Path):
    """Scatter: knowledge_entropy vs total_tokens with regression line."""
    pass_df = df[(df["outcome"] == "PASS") & (df["knowledge_entropy"].notna()) & (df["knowledge_entropy"] != "")]

    if len(pass_df) < 3:
        print("  [SKIP] entropy_correlation -- insufficient data with entropy scores")
        return

    pass_df = pass_df.copy()
    pass_df["knowledge_entropy"] = pd.to_numeric(pass_df["knowledge_entropy"], errors="coerce")
    pass_df = pass_df.dropna(subset=["knowledge_entropy"])

    if len(pass_df) < 3:
        print("  [SKIP] entropy_correlation -- insufficient numeric entropy data")
        return

    fig, ax = plt.subplots(figsize=(8, 6))

    for condition in ["control", "treatment"]:
        cond_df = pass_df[pass_df["condition"] == condition]
        if len(cond_df) > 0:
            ax.scatter(cond_df["knowledge_entropy"], cond_df["total_tokens"],
                       color=COLORS[condition], label=condition.capitalize(),
                       alpha=0.7, s=50)

    # Regression line across all data
    x = pass_df["knowledge_entropy"].values
    y = pass_df["total_tokens"].values
    if len(x) >= 3:
        z = np.polyfit(x, y, 1)
        p = np.poly1d(z)
        x_line = np.linspace(x.min(), x.max(), 100)
        ax.plot(x_line, p(x_line), "--", color=COLORS["neutral"], alpha=0.7)

        # R-squared
        ss_res = np.sum((y - p(x)) ** 2)
        ss_tot = np.sum((y - np.mean(y)) ** 2)
        r_squared = 1 - (ss_res / ss_tot) if ss_tot > 0 else 0
        ax.text(0.05, 0.95, f"R² = {r_squared:.3f}",
                transform=ax.transAxes, fontsize=10, verticalalignment="top")

    apply_style(ax, "Knowledge Entropy vs Token Consumption",
                "Knowledge Entropy Score", "Total Tokens")
    ax.legend()
    fig.tight_layout()

    for fmt in ["png", "svg"]:
        fig.savefig(output_dir / f"entropy_correlation.{fmt}", dpi=DPI)
    plt.close(fig)
    print("  [OK] entropy_correlation")


def chart_tool_distribution(df: pd.DataFrame, output_dir: Path):
    """Bar chart: RTMX tool call counts for treatment condition."""
    treatment = df[(df["condition"] == "treatment") & (df["outcome"] == "PASS")]

    if len(treatment) == 0 or treatment["tool_calls_rtmx"].sum() == 0:
        print("  [SKIP] tool_distribution -- no RTMX tool data")
        return

    fig, ax = plt.subplots(figsize=(8, 5))

    # Aggregate tool calls
    ax.bar(["RTMX Tools", "Other Tools"],
           [treatment["tool_calls_rtmx"].mean(), treatment["tool_calls_other"].mean()],
           color=[COLORS["rtmx"], COLORS["neutral"]], alpha=0.85)

    apply_style(ax, "Tool Call Distribution (Treatment)", "", "Mean Tool Calls per Session")
    fig.tight_layout()

    for fmt in ["png", "svg"]:
        fig.savefig(output_dir / f"tool_distribution.{fmt}", dpi=DPI)
    plt.close(fig)
    print("  [OK] tool_distribution")


def chart_amortization(df: pd.DataFrame, output_dir: Path):
    """Line chart: cumulative tokens per task over sequential tasks."""
    # This only applies to multi-task experiments
    pass_df = df[df["outcome"] == "PASS"].copy()

    experiments = pass_df["experiment"].unique()
    multi_task = []
    for exp in experiments:
        exp_df = pass_df[pass_df["experiment"] == exp]
        if exp_df["run_number"].max() > 1:
            multi_task.append(exp)

    if not multi_task:
        print("  [SKIP] amortization -- no multi-task experiments")
        return

    fig, ax = plt.subplots(figsize=(8, 5))

    for exp in multi_task:
        for condition in ["control", "treatment"]:
            cond_df = pass_df[(pass_df["experiment"] == exp) & (pass_df["condition"] == condition)]
            cond_df = cond_df.sort_values("run_number")

            if len(cond_df) < 2:
                continue

            cumulative = cond_df["total_tokens"].cumsum()
            tasks = range(1, len(cumulative) + 1)
            per_task = [cumulative.iloc[i] / (i + 1) for i in range(len(cumulative))]

            ax.plot(list(tasks), per_task, marker="o", color=COLORS[condition],
                    label=f"{exp} ({condition})", alpha=0.85)

    apply_style(ax, "Planning Amortization Curve",
                "Cumulative Tasks Completed", "Tokens per Completed Task")
    ax.legend()
    fig.tight_layout()

    for fmt in ["png", "svg"]:
        fig.savefig(output_dir / f"amortization.{fmt}", dpi=DPI)
    plt.close(fig)
    print("  [OK] amortization")


def main():
    ledger_path = sys.argv[1] if len(sys.argv) > 1 else "results/summary.csv"

    if not Path(ledger_path).exists():
        print(f"ERROR: Ledger not found: {ledger_path}", file=sys.stderr)
        sys.exit(1)

    output_dir = Path("results/charts")
    output_dir.mkdir(parents=True, exist_ok=True)

    df = load_data(ledger_path)
    if len(df) == 0:
        print("No data to visualize.")
        sys.exit(0)

    print("Generating charts...")
    chart_token_comparison(df, output_dir)
    chart_token_breakdown(df, output_dir)
    chart_completion_rate(df, output_dir)
    chart_entropy_correlation(df, output_dir)
    chart_tool_distribution(df, output_dir)
    chart_amortization(df, output_dir)
    print(f"Charts written to {output_dir}/")


if __name__ == "__main__":
    main()
