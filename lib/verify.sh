#!/usr/bin/env bash
# verify.sh -- Test execution and outcome classification
# REQ-HARNESS-004: Outcome verification runs test suite independently
set -euo pipefail

# Verify task outcome by running the test command
# Args: workdir test_command output_file
# Sets: VERIFY_OUTCOME, VERIFY_TOTAL, VERIFY_PASSED, VERIFY_FAILED
verify_outcome() {
    local workdir="${1:?workdir required}"
    local test_command="${2:?test_command required}"
    local output_file="${3:?output_file required}"

    VERIFY_OUTCOME="ERROR"
    VERIFY_TOTAL=0
    VERIFY_PASSED=0
    VERIFY_FAILED=0

    if [[ ! -d "$workdir" ]]; then
        echo "ERROR: Working directory not found: $workdir" >&2
        return 0  # Return 0 because ERROR is valid data, not an infrastructure crash
    fi

    local exit_code=0
    # Timeout after 120s to prevent hanging test processes (e.g. unclosed servers)
    timeout 120 bash -c "cd \"$workdir\" && eval \"$test_command\"" > "$output_file" 2>&1 || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        VERIFY_OUTCOME="PASS"
    fi

    # Attempt to parse test counts from common frameworks
    # Go: ok/FAIL lines, "--- PASS:", "--- FAIL:"
    # Python: "X passed, Y failed" or "Ran X tests"
    # Node: "X passing", "X failing"
    if [[ -f "$output_file" ]]; then
        # Go test output: count "--- PASS:" and "--- FAIL:" lines
        local go_pass go_fail
        go_pass=$(grep -c -F -- '--- PASS:' "$output_file" 2>/dev/null || true)
        go_pass=${go_pass:-0}
        go_fail=$(grep -c -F -- '--- FAIL:' "$output_file" 2>/dev/null || true)
        go_fail=${go_fail:-0}

        # Jest output: "Tests: N passed, N total" (must check before generic "N passed")
        local jest_pass jest_fail
        jest_pass=$(grep -E '^Tests:' "$output_file" 2>/dev/null | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' || true)
        jest_pass=${jest_pass:-0}
        jest_fail=$(grep -E '^Tests:' "$output_file" 2>/dev/null | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+' || true)
        jest_fail=${jest_fail:-0}

        # Python pytest output: "N passed", "N failed"
        local py_pass py_fail
        py_pass=$(grep -oE '[0-9]+ passed' "$output_file" 2>/dev/null | tail -1 | grep -oE '[0-9]+' || true)
        py_pass=${py_pass:-0}
        py_fail=$(grep -oE '[0-9]+ failed' "$output_file" 2>/dev/null | tail -1 | grep -oE '[0-9]+' || true)
        py_fail=${py_fail:-0}

        # Node/mocha output: "N passing", "N failing"
        local node_pass node_fail
        node_pass=$(grep -oE '[0-9]+ passing' "$output_file" 2>/dev/null | head -1 | grep -oE '[0-9]+' || true)
        node_pass=${node_pass:-0}
        node_fail=$(grep -oE '[0-9]+ failing' "$output_file" 2>/dev/null | head -1 | grep -oE '[0-9]+' || true)
        node_fail=${node_fail:-0}

        # Use whichever framework produced nonzero results (Jest first, most specific)
        if [[ $((jest_pass + jest_fail)) -gt 0 ]]; then
            VERIFY_PASSED=$jest_pass
            VERIFY_FAILED=$jest_fail
        elif [[ $((go_pass + go_fail)) -gt 0 ]]; then
            VERIFY_PASSED=$go_pass
            VERIFY_FAILED=$go_fail
        elif [[ $((py_pass + py_fail)) -gt 0 ]]; then
            VERIFY_PASSED=$py_pass
            VERIFY_FAILED=$py_fail
        elif [[ $((node_pass + node_fail)) -gt 0 ]]; then
            VERIFY_PASSED=$node_pass
            VERIFY_FAILED=$node_fail
        fi

        VERIFY_TOTAL=$((VERIFY_PASSED + VERIFY_FAILED))
    fi

    # Classify outcome
    if [[ $exit_code -eq 0 ]]; then
        VERIFY_OUTCOME="PASS"
    elif [[ $VERIFY_PASSED -gt 0 && $VERIFY_FAILED -gt 0 ]]; then
        VERIFY_OUTCOME="PARTIAL"
    elif [[ $VERIFY_TOTAL -eq 0 ]]; then
        # No tests detected at all -- likely build failure
        VERIFY_OUTCOME="FAIL"
    else
        VERIFY_OUTCOME="FAIL"
    fi
}
