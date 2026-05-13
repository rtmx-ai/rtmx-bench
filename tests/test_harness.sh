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

rm -rf "$verify_tmpdir"

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
