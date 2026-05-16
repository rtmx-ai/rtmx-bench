#!/usr/bin/env bash
# collect_results.sh -- Run all test suites, produce RTMX results JSON
# Used by: rtmx verify --results tests/results.json --update
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BENCH_DIR="$(dirname "$SCRIPT_DIR")"
RESULTS_FILE="${1:-$SCRIPT_DIR/results.json}"

results=()

# Run a shell test suite and map exit code to pass/fail for given req IDs
run_shell_test() {
    local test_file="$1"
    shift
    local req_ids=("$@")

    local status="pass"
    local test_name
    test_name=$(basename "$test_file" .sh)

    if bash "$BENCH_DIR/$test_file" >/dev/null 2>&1; then
        status="pass"
    else
        status="fail"
    fi

    for req_id in "${req_ids[@]}"; do
        results+=("{\"req_id\":\"$req_id\",\"test_name\":\"$test_name\",\"test_file\":\"$test_file\",\"status\":\"$status\"}")
    done
}

# Run a Python test file and map individual test results to req IDs
run_python_tests() {
    local test_file="$1"
    shift
    # Remaining args are pairs: test_function req_id
    local test_name
    test_name=$(basename "$test_file" .py)

    while [[ $# -ge 2 ]]; do
        local func="$1" req_id="$2"
        shift 2

        local status="pass"
        if python3 -m pytest "$BENCH_DIR/$test_file::$func" -x -q --no-header --tb=no -p no:asyncio 2>/dev/null | grep -q "passed"; then
            status="pass"
        else
            status="fail"
        fi

        results+=("{\"req_id\":\"$req_id\",\"test_name\":\"$func\",\"test_file\":\"$test_file\",\"status\":\"$status\"}")
    done
}

echo "Collecting test results..."

# Shell test suites
run_shell_test "tests/test_harness.sh" \
    "REQ-HARNESS-001" "REQ-HARNESS-003" "REQ-HARNESS-004" "REQ-DATA-001" \
    "REQ-HARNESS-006" "REQ-HARNESS-007" "REQ-HARNESS-008"

run_shell_test "tests/test_treatment.sh" \
    "REQ-EXP-001" "REQ-EXP-004" "REQ-EXP-005"

run_shell_test "tests/test_telemetry.sh" \
    "REQ-HARNESS-002"

run_shell_test "tests/test_entropy.sh" \
    "REQ-ENTROPY-001" "REQ-ENTROPY-007"

run_shell_test "tests/test_staleness.sh" \
    "REQ-ENTROPY-002"

# Python test suites (map specific functions to requirements)
run_python_tests "tests/test_analysis.py" \
    "test_analyze_experiment" "REQ-HARNESS-005" \
    "test_idempotency_cache" "REQ-DATA-004" \
    "test_chart_generation" "REQ-DATA-003" \
    "test_entropy_correlation" "REQ-ENTROPY-006"

run_python_tests "tests/test_entropy_advanced.py" \
    "test_duplication_score" "REQ-ENTROPY-004" \
    "test_composite_all_dimensions" "REQ-ENTROPY-005"

# Build JSON array
json="["
for i in "${!results[@]}"; do
    if [[ $i -gt 0 ]]; then
        json+=","
    fi
    json+="${results[$i]}"
done
json+="]"

echo "$json" | python3 -m json.tool > "$RESULTS_FILE"
echo "Results written to $RESULTS_FILE (${#results[@]} entries)"
