#!/usr/bin/env python3
"""Tests for statistical analysis module.

REQ-HARNESS-005: Statistical analysis computes significance tests
and amortization curves from experiment results.
"""

import csv
import json
import os
import sys
import tempfile
from pathlib import Path

# Add parent to path
sys.path.insert(0, str(Path(__file__).parent.parent / "analysis"))
import compare


def create_test_ledger(rows: list[dict]) -> str:
    """Create a temporary CSV ledger with test data."""
    tmpdir = tempfile.mkdtemp()
    path = os.path.join(tmpdir, "summary.csv")
    columns = [
        "session_id", "timestamp", "experiment", "condition", "run_number",
        "model", "prompt_sha256", "input_tokens", "output_tokens",
        "total_tokens", "rtmx_tokens", "planning_tokens", "execution_tokens",
        "turns", "backtracks", "tool_calls_rtmx", "tool_calls_other",
        "outcome", "tests_total", "tests_passed", "tests_failed",
        "wall_clock_seconds", "knowledge_entropy", "transcript_path",
    ]
    with open(path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=columns)
        writer.writeheader()
        for row in rows:
            full_row = {c: "" for c in columns}
            full_row.update(row)
            writer.writerow(full_row)
    return path


def make_row(condition: str, total_tokens: int, outcome: str = "PASS",
             experiment: str = "test-exp", **kwargs) -> dict:
    """Helper to create a test row with defaults."""
    return {
        "session_id": f"test-{condition}-{total_tokens}",
        "timestamp": "2026-05-13T00:00:00Z",
        "experiment": experiment,
        "condition": condition,
        "run_number": "1",
        "model": "claude-sonnet-4-20250514",
        "prompt_sha256": "abc123",
        "input_tokens": str(total_tokens // 2),
        "output_tokens": str(total_tokens - total_tokens // 2),
        "total_tokens": str(total_tokens),
        "rtmx_tokens": str(kwargs.get("rtmx_tokens", 0)),
        "planning_tokens": str(kwargs.get("planning_tokens", total_tokens // 3)),
        "execution_tokens": str(kwargs.get("execution_tokens", total_tokens * 2 // 3)),
        "turns": str(kwargs.get("turns", 10)),
        "backtracks": str(kwargs.get("backtracks", 2)),
        "tool_calls_rtmx": str(kwargs.get("tool_calls_rtmx", 0)),
        "tool_calls_other": str(kwargs.get("tool_calls_other", 20)),
        "outcome": outcome,
        "tests_total": "10",
        "tests_passed": "10" if outcome == "PASS" else "5",
        "tests_failed": "0" if outcome == "PASS" else "5",
        "wall_clock_seconds": "120.0",
        "knowledge_entropy": "",
        "transcript_path": "results/raw/test",
    }


def test_load_ledger():
    """Test ledger loading and validation."""
    path = create_test_ledger([
        make_row("control", 10000),
        make_row("treatment", 8000),
    ])
    df = compare.load_ledger(path)
    assert len(df) == 2
    assert "total_tokens" in df.columns
    print("  [PASS] load_ledger")


def test_filter_pass():
    """Test filtering to PASS outcomes only."""
    path = create_test_ledger([
        make_row("control", 10000, "PASS"),
        make_row("control", 15000, "FAIL"),
        make_row("control", 12000, "PARTIAL"),
    ])
    df = compare.load_ledger(path)
    passed = compare.filter_pass(df)
    assert len(passed) == 1
    assert int(passed.iloc[0]["total_tokens"]) == 10000
    print("  [PASS] filter_pass")


def test_compute_stats():
    """Test summary statistics computation."""
    import pandas as pd
    s = pd.Series([100, 200, 300])
    stats = compare.compute_stats(s)
    assert stats["mean"] == 200.0
    assert stats["median"] == 200.0
    assert stats["n"] == 3
    print("  [PASS] compute_stats")


def test_compute_stats_empty():
    """Test stats on empty series."""
    import pandas as pd
    stats = compare.compute_stats(pd.Series([], dtype=float))
    assert stats["n"] == 0
    assert stats["mean"] == 0
    print("  [PASS] compute_stats_empty")


def test_bootstrap_ci():
    """Test bootstrap confidence interval."""
    import pandas as pd
    a = pd.Series([100, 110, 105, 95, 100])
    b = pd.Series([80, 85, 82, 78, 80])
    result = compare.bootstrap_ci(a, b)
    assert result["ratio"] > 1.0  # a > b, so ratio > 1
    assert result["ci_lower"] > 0
    assert result["ci_upper"] > result["ci_lower"]
    print("  [PASS] bootstrap_ci")


def test_analyze_experiment():
    """Test full experiment analysis."""
    rows = []
    for i in range(5):
        rows.append(make_row("control", 10000 + i * 500, turns=10 + i, backtracks=2))
        rows.append(make_row("treatment", 7000 + i * 300, turns=7 + i, backtracks=1,
                             rtmx_tokens=200, tool_calls_rtmx=5))
    path = create_test_ledger(rows)
    df = compare.load_ledger(path)
    result = compare.analyze_experiment(df, "test-exp")

    assert result["experiment"] == "test-exp"
    assert result["runs"]["control"] == 5
    assert result["runs"]["treatment"] == 5
    assert result["completion_rate"]["control"] == 1.0
    assert result["completion_rate"]["treatment"] == 1.0
    assert "token_efficiency" in result
    assert result["token_efficiency"]["ratio"] > 1.0  # control > treatment
    assert "mann_whitney" in result
    assert "warnings" not in result  # n=5 is sufficient
    print("  [PASS] analyze_experiment")


def test_analyze_insufficient_runs():
    """Test warning for insufficient runs."""
    rows = [
        make_row("control", 10000),
        make_row("treatment", 8000),
    ]
    path = create_test_ledger(rows)
    df = compare.load_ledger(path)
    result = compare.analyze_experiment(df, "test-exp")

    assert "warnings" in result
    assert len(result["warnings"]) == 2  # both conditions < 5
    print("  [PASS] analyze_insufficient_runs")


def test_error_outcomes_excluded():
    """Test that ERROR outcomes are filtered from analysis."""
    rows = [
        make_row("control", 10000, "PASS"),
        make_row("control", 99999, "ERROR"),  # should be excluded
        make_row("treatment", 8000, "PASS"),
    ]
    path = create_test_ledger(rows)
    df = compare.load_ledger(path)
    result = compare.analyze_experiment(df, "test-exp")

    # ERROR run should not count toward stats
    assert result["runs"]["control"] == 1  # only non-ERROR
    print("  [PASS] error_outcomes_excluded")


def main():
    print("=== Statistical Analysis Tests ===")
    tests = [
        test_load_ledger,
        test_filter_pass,
        test_compute_stats,
        test_compute_stats_empty,
        test_bootstrap_ci,
        test_analyze_experiment,
        test_analyze_insufficient_runs,
        test_error_outcomes_excluded,
    ]

    passed = 0
    failed = 0
    for test in tests:
        try:
            test()
            passed += 1
        except Exception as e:
            print(f"  [FAIL] {test.__name__}: {e}")
            failed += 1

    print(f"\n=== Results: {passed} passed, {failed} failed ===")
    sys.exit(0 if failed == 0 else 1)


if __name__ == "__main__":
    main()
