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
    # Timeout after 300s to allow dependency installation + test execution
    # REQ-HARNESS-007: Use process group so timeout kills all children
    timeout --foreground 300 bash -c "cd \"$workdir\" && eval \"$test_command\"" > "$output_file" 2>&1 || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        VERIFY_OUTCOME="PASS"
    fi

    # REQ-HARNESS-007: Track timeout for classification
    local timed_out=0
    if [[ $exit_code -eq 124 ]]; then
        timed_out=1
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

        # Vitest output: "Tests  N passed" or "Tests  N failed | N passed"
        local vitest_pass vitest_fail
        vitest_pass=$(grep -E '^\s*Tests\s' "$output_file" 2>/dev/null | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' || true)
        vitest_pass=${vitest_pass:-0}
        vitest_fail=$(grep -E '^\s*Tests\s' "$output_file" 2>/dev/null | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+' || true)
        vitest_fail=${vitest_fail:-0}

        # Rust/cargo test: "test result: ok. N passed; N failed"
        local rust_pass rust_fail
        rust_pass=$(grep -oE 'test result:.*[0-9]+ passed' "$output_file" 2>/dev/null | tail -1 | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' || true)
        rust_pass=${rust_pass:-0}
        rust_fail=$(grep -oE 'test result:.*[0-9]+ failed' "$output_file" 2>/dev/null | tail -1 | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+' || true)
        rust_fail=${rust_fail:-0}

        # Bun test: "N pass" / "N fail"
        local bun_pass bun_fail
        bun_pass=$(grep -oE '[0-9]+ pass$' "$output_file" 2>/dev/null | head -1 | grep -oE '[0-9]+' || true)
        bun_pass=${bun_pass:-0}
        bun_fail=$(grep -oE '[0-9]+ fail$' "$output_file" 2>/dev/null | head -1 | grep -oE '[0-9]+' || true)
        bun_fail=${bun_fail:-0}

        # Generic summary: "Passed: N" / "Failed: N" or "Total tests: N"
        local generic_pass generic_fail
        generic_pass=$(grep -iE '^\[?TEST\]?\s*Passed:\s*[0-9]+' "$output_file" 2>/dev/null | tail -1 | grep -oE '[0-9]+' || true)
        generic_pass=${generic_pass:-0}
        generic_fail=$(grep -iE '^\[?TEST\]?\s*Failed:\s*[0-9]+' "$output_file" 2>/dev/null | tail -1 | grep -oE '[0-9]+' || true)
        generic_fail=${generic_fail:-0}

        # TAP format: count "ok" and "not ok" lines
        local tap_pass tap_fail
        tap_pass=$(grep -cE '^ok [0-9]' "$output_file" 2>/dev/null || true)
        tap_pass=${tap_pass:-0}
        tap_fail=$(grep -cE '^not ok [0-9]' "$output_file" 2>/dev/null || true)
        tap_fail=${tap_fail:-0}

        # Checkmark/cross counting: lines with checkmark or cross characters
        local check_pass check_fail
        check_pass=$(grep -cE '^\s*(\[TEST\]\s*)?(✓|✅|PASS\b)' "$output_file" 2>/dev/null || true)
        check_pass=${check_pass:-0}
        check_fail=$(grep -cE '^\s*(\[TEST\]\s*)?(✗|✘|❌|FAIL\b)' "$output_file" 2>/dev/null || true)
        check_fail=${check_fail:-0}

        # Use whichever framework produced nonzero results (most specific first)
        if [[ $((jest_pass + jest_fail)) -gt 0 ]]; then
            VERIFY_PASSED=$jest_pass
            VERIFY_FAILED=$jest_fail
        elif [[ $((go_pass + go_fail)) -gt 0 ]]; then
            VERIFY_PASSED=$go_pass
            VERIFY_FAILED=$go_fail
        elif [[ $((py_pass + py_fail)) -gt 0 ]]; then
            VERIFY_PASSED=$py_pass
            VERIFY_FAILED=$py_fail
        elif [[ $((vitest_pass + vitest_fail)) -gt 0 ]]; then
            VERIFY_PASSED=$vitest_pass
            VERIFY_FAILED=$vitest_fail
        elif [[ $((rust_pass + rust_fail)) -gt 0 ]]; then
            VERIFY_PASSED=$rust_pass
            VERIFY_FAILED=$rust_fail
        elif [[ $((node_pass + node_fail)) -gt 0 ]]; then
            VERIFY_PASSED=$node_pass
            VERIFY_FAILED=$node_fail
        elif [[ $((bun_pass + bun_fail)) -gt 0 ]]; then
            VERIFY_PASSED=$bun_pass
            VERIFY_FAILED=$bun_fail
        elif [[ $((generic_pass + generic_fail)) -gt 0 ]]; then
            VERIFY_PASSED=$generic_pass
            VERIFY_FAILED=$generic_fail
        elif [[ $((tap_pass + tap_fail)) -gt 0 ]]; then
            VERIFY_PASSED=$tap_pass
            VERIFY_FAILED=$tap_fail
        elif [[ $((check_pass + check_fail)) -gt 0 ]]; then
            VERIFY_PASSED=$check_pass
            VERIFY_FAILED=$check_fail
        fi

        VERIFY_TOTAL=$((VERIFY_PASSED + VERIFY_FAILED))
    fi

    # Classify outcome (REQ-HARNESS-007: distinguish TIMEOUT from FAIL)
    if [[ $exit_code -eq 0 ]]; then
        VERIFY_OUTCOME="PASS"
    elif [[ $timed_out -eq 1 ]]; then
        VERIFY_OUTCOME="TIMEOUT"
    elif [[ $VERIFY_PASSED -gt 0 && $VERIFY_FAILED -gt 0 ]]; then
        VERIFY_OUTCOME="PARTIAL"
    elif [[ $VERIFY_TOTAL -eq 0 ]]; then
        # No tests detected at all -- likely build failure
        VERIFY_OUTCOME="FAIL"
    else
        VERIFY_OUTCOME="FAIL"
    fi
}
