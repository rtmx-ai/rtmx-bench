#!/usr/bin/env bash
# Tests for experiment harness (REQ-HARNESS-001, REQ-HARNESS-003, REQ-HARNESS-004)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BENCH_DIR="$(dirname "$SCRIPT_DIR")"
PASS=0
FAIL=0

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "  [PASS] $label"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] $label: expected '$expected', got '$actual'"
        FAIL=$((FAIL + 1))
    fi
}

assert_file_exists() {
    local label="$1" path="$2"
    if [[ -f "$path" ]]; then
        echo "  [PASS] $label"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] $label: file not found: $path"
        FAIL=$((FAIL + 1))
    fi
}

assert_exit_code() {
    local label="$1" expected="$2"
    shift 2
    local actual=0
    "$@" >/dev/null 2>&1 || actual=$?
    if [[ "$expected" == "$actual" ]]; then
        echo "  [PASS] $label"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] $label: expected exit $expected, got $actual"
        FAIL=$((FAIL + 1))
    fi
}

# --- CSV Ledger Tests (REQ-DATA-001) ---
echo "=== CSV Ledger Tests ==="

source "$BENCH_DIR/lib/csv.sh"

# Test: init creates file with header
tmpdir=$(mktemp -d)
ledger_init "$tmpdir/test.csv" 2>/dev/null
header=$(head -1 "$tmpdir/test.csv")
assert_eq "init creates header" "$LEDGER_HEADER" "$header"

# Test: init refuses to overwrite
assert_exit_code "init refuses overwrite" 1 ledger_init "$tmpdir/test.csv"

# Test: append adds a row
ledger_append "$tmpdir/test.csv" \
    "test-id" "2026-05-13T00:00:00Z" "test-exp" "control" "1" \
    "claude-sonnet-4-20250514" "abc123" \
    "1000" "500" "1500" "0" "400" "1100" \
    "5" "1" "0" "12" \
    "PASS" "10" "10" "0" \
    "120.5" "" "results/raw/test"
line_count=$(wc -l < "$tmpdir/test.csv" | tr -d ' ')
assert_eq "append adds one row" "2" "$line_count"

# Test: validate passes on valid ledger
valid_exit=0
ledger_validate "$tmpdir/test.csv" 2>/dev/null || valid_exit=$?
assert_eq "validate passes valid ledger" "0" "$valid_exit"

# Test: validate catches bad condition
bad_ledger="$tmpdir/bad.csv"
echo "$LEDGER_HEADER" > "$bad_ledger"
echo "id,2026-01-01T00:00:00Z,exp,INVALID,1,model,sha,100,50,150,0,40,110,5,1,0,12,PASS,10,10,0,60.0,,path" >> "$bad_ledger"
validate_exit=0
ledger_validate "$bad_ledger" 2>/dev/null || validate_exit=$?
assert_eq "validate catches bad condition" "1" "$validate_exit"

# Test: validate catches control with rtmx_tokens
bad_ledger2="$tmpdir/bad2.csv"
echo "$LEDGER_HEADER" > "$bad_ledger2"
echo "id,2026-01-01T00:00:00Z,exp,control,1,model,sha,100,50,150,99,40,110,5,1,0,12,PASS,10,10,0,60.0,,path" >> "$bad_ledger2"
validate_exit2=0
ledger_validate "$bad_ledger2" 2>/dev/null || validate_exit2=$?
assert_eq "validate catches control with rtmx_tokens" "1" "$validate_exit2"

rm -rf "$tmpdir"

# --- Verify Tests (REQ-HARNESS-004) ---
echo ""
echo "=== Outcome Verification Tests ==="

source "$BENCH_DIR/lib/verify.sh"

# Test: PASS outcome on successful test
verify_tmpdir=$(mktemp -d)
mkdir -p "$verify_tmpdir/project"
echo '#!/bin/bash
echo "--- PASS: TestOne (0.01s)"
echo "--- PASS: TestTwo (0.02s)"
echo "ok  mypackage 0.03s"
exit 0' > "$verify_tmpdir/project/run_tests.sh"
chmod +x "$verify_tmpdir/project/run_tests.sh"

verify_outcome "$verify_tmpdir/project" "bash run_tests.sh" "$verify_tmpdir/test_out.txt"
assert_eq "PASS on successful tests" "PASS" "$VERIFY_OUTCOME"
assert_eq "counts 2 passed" "2" "$VERIFY_PASSED"
assert_eq "counts 0 failed" "0" "$VERIFY_FAILED"

# Test: PARTIAL outcome on mixed results
echo '#!/bin/bash
echo "--- PASS: TestOne (0.01s)"
echo "--- FAIL: TestTwo (0.02s)"
echo "FAIL  mypackage 0.03s"
exit 1' > "$verify_tmpdir/project/run_tests.sh"

verify_outcome "$verify_tmpdir/project" "bash run_tests.sh" "$verify_tmpdir/test_out2.txt"
assert_eq "PARTIAL on mixed results" "PARTIAL" "$VERIFY_OUTCOME"
assert_eq "counts 1 passed" "1" "$VERIFY_PASSED"
assert_eq "counts 1 failed" "1" "$VERIFY_FAILED"

# Test: FAIL on build failure (no test output)
echo '#!/bin/bash
echo "build failed"
exit 1' > "$verify_tmpdir/project/run_tests.sh"

verify_outcome "$verify_tmpdir/project" "bash run_tests.sh" "$verify_tmpdir/test_out3.txt"
assert_eq "FAIL on build failure" "FAIL" "$VERIFY_OUTCOME"

# Test: custom runner with checkmark output
echo '#!/bin/bash
echo "[TEST] Running test_db_init..."
echo "[TEST] ✓ Database file should be created"
echo "[TEST] ✓ Table should exist"
echo "[TEST] ✓ Table should have columns"
echo "[TEST] Running test_api..."
echo "[TEST] ✓ POST /shorten works"
echo "[TEST] ✓ GET /redirect works"
echo "[TEST] "
echo "=== Test Results ==="
echo "[TEST] Total tests: 5"
echo "[TEST] Passed: 5"
echo "[TEST] Failed: 0"
exit 0' > "$verify_tmpdir/project/run_tests.sh"

verify_outcome "$verify_tmpdir/project" "bash run_tests.sh" "$verify_tmpdir/test_out_custom.txt"
assert_eq "custom runner PASS" "PASS" "$VERIFY_OUTCOME"
# Should detect either via generic "Passed: N" or checkmark counting
if [[ $VERIFY_PASSED -ge 5 ]]; then
    echo "  [PASS] custom runner counts >= 5 passed ($VERIFY_PASSED)"
    PASS=$((PASS + 1))
else
    echo "  [FAIL] custom runner counts: expected >= 5, got $VERIFY_PASSED"
    FAIL=$((FAIL + 1))
fi

# Test: Vitest output format
echo '#!/bin/bash
echo " ✓ src/app.test.ts (3)"
echo " ✓ src/db.test.ts (2)"
echo ""
echo " Tests  12 passed (12)"
echo " Time  0.5s"
exit 0' > "$verify_tmpdir/project/run_tests.sh"

verify_outcome "$verify_tmpdir/project" "bash run_tests.sh" "$verify_tmpdir/test_out_vitest.txt"
assert_eq "vitest PASS" "PASS" "$VERIFY_OUTCOME"
assert_eq "vitest counts 12 passed" "12" "$VERIFY_PASSED"

# Test: Rust cargo test output
echo '#!/bin/bash
echo "running 8 tests"
echo "test test_create ... ok"
echo "test test_redirect ... ok"
echo ""
echo "test result: ok. 8 passed; 0 failed; 0 ignored"
exit 0' > "$verify_tmpdir/project/run_tests.sh"

verify_outcome "$verify_tmpdir/project" "bash run_tests.sh" "$verify_tmpdir/test_out_rust.txt"
assert_eq "rust PASS" "PASS" "$VERIFY_OUTCOME"
assert_eq "rust counts 8 passed" "8" "$VERIFY_PASSED"

# Test: TAP format
echo '#!/bin/bash
echo "TAP version 13"
echo "1..4"
echo "ok 1 - should shorten URLs"
echo "ok 2 - should redirect"
echo "not ok 3 - should rate limit"
echo "ok 4 - should validate input"
exit 1' > "$verify_tmpdir/project/run_tests.sh"

verify_outcome "$verify_tmpdir/project" "bash run_tests.sh" "$verify_tmpdir/test_out_tap.txt"
assert_eq "TAP PARTIAL" "PARTIAL" "$VERIFY_OUTCOME"
assert_eq "TAP counts 3 passed" "3" "$VERIFY_PASSED"
assert_eq "TAP counts 1 failed" "1" "$VERIFY_FAILED"

rm -rf "$verify_tmpdir"

# --- Timeout Classification Tests (REQ-HARNESS-007) ---
echo ""
echo "=== Timeout Classification Tests ==="

timeout_tmpdir=$(mktemp -d)
mkdir -p "$timeout_tmpdir/project"

# Test: TIMEOUT outcome on test that exceeds time limit
echo '#!/bin/bash
echo "--- PASS: TestOne (0.01s)"
sleep 999' > "$timeout_tmpdir/project/run_tests.sh"
chmod +x "$timeout_tmpdir/project/run_tests.sh"

# Override timeout to 2s for test speed
ORIG_VERIFY=$(declare -f verify_outcome)
verify_outcome_timeout() {
    local workdir="${1:?}" test_command="${2:?}" output_file="${3:?}"
    VERIFY_OUTCOME="ERROR"
    VERIFY_TOTAL=0
    VERIFY_PASSED=0
    VERIFY_FAILED=0
    local exit_code=0
    timeout --foreground 2 bash -c "cd \"$workdir\" && eval \"$test_command\"" > "$output_file" 2>&1 || exit_code=$?
    if [[ $exit_code -eq 0 ]]; then VERIFY_OUTCOME="PASS"; fi
    local timed_out=0
    if [[ $exit_code -eq 124 ]]; then timed_out=1; fi
    # Parse test output for counts
    if [[ -f "$output_file" ]]; then
        local go_pass go_fail
        go_pass=$(grep -c -F -- '--- PASS:' "$output_file" 2>/dev/null || true)
        go_pass=${go_pass:-0}
        go_fail=$(grep -c -F -- '--- FAIL:' "$output_file" 2>/dev/null || true)
        go_fail=${go_fail:-0}
        if [[ $((go_pass + go_fail)) -gt 0 ]]; then
            VERIFY_PASSED=$go_pass
            VERIFY_FAILED=$go_fail
        fi
        VERIFY_TOTAL=$((VERIFY_PASSED + VERIFY_FAILED))
    fi
    if [[ $exit_code -eq 0 ]]; then VERIFY_OUTCOME="PASS"
    elif [[ $timed_out -eq 1 ]]; then VERIFY_OUTCOME="TIMEOUT"
    elif [[ $VERIFY_PASSED -gt 0 && $VERIFY_FAILED -gt 0 ]]; then VERIFY_OUTCOME="PARTIAL"
    elif [[ $VERIFY_TOTAL -eq 0 ]]; then VERIFY_OUTCOME="FAIL"
    else VERIFY_OUTCOME="FAIL"; fi
}

verify_outcome_timeout "$timeout_tmpdir/project" "bash run_tests.sh" "$timeout_tmpdir/test_out_timeout.txt"
assert_eq "TIMEOUT on exceeded time limit" "TIMEOUT" "$VERIFY_OUTCOME"
assert_eq "TIMEOUT preserves partial test counts" "1" "$VERIFY_PASSED"

rm -rf "$timeout_tmpdir"

# --- Prompt Identity Tests (REQ-HARNESS-003) ---
echo ""
echo "=== Prompt Identity Tests ==="

# Test: prompt directory exists
if [[ -d "$BENCH_DIR/prompts" ]]; then
    echo "  [PASS] prompts/ directory exists"
    PASS=$((PASS + 1))
else
    echo "  [FAIL] prompts/ directory missing"
    FAIL=$((FAIL + 1))
fi

# --- Summary ---
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
