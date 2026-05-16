# REQ-HARNESS-007: Outcome Classification

## Status: MISSING
## Priority: P0
## Phase: 1

## Requirement

rtmx-bench shall distinguish timeout outcomes from test failures in
the verification step, recording TIMEOUT as a separate outcome class
in the experiment ledger.

## Rationale

The `timeout` command returns exit code 124 when it kills a process,
but verify.sh treats all non-zero exit codes identically as failures.
This conflates two fundamentally different situations: (1) the agent
built a broken application (FAIL), and (2) the agent's tests ran out
of time, often due to dependency installation (TIMEOUT). Treatment
run 3 (721a6d42) completed 28/29 tests before timeout killed pytest
during pip install, producing a false FAIL in the ledger.

## Acceptance Criteria

1. Exit code 124 from the timeout command sets VERIFY_OUTCOME to
   "TIMEOUT" instead of "FAIL"
2. TIMEOUT is a valid value in the outcome column of summary.csv
3. ledger_validate accepts TIMEOUT as a valid outcome
4. After a timeout, child processes spawned by the test command
   are explicitly killed (not left as orphans)
5. The analysis engine (compare.py) treats TIMEOUT runs as
   non-PASS (excluded from token efficiency calculations) but
   distinguishes them from FAIL in reporting
6. Test output captured before the timeout is still parsed for
   test counts (partial results are data)

## Dependencies

- REQ-HARNESS-004: Outcome verification (provides the classification logic)
- REQ-HARNESS-006: Process isolation (provides cleanup infrastructure)

## Files to Modify

- `lib/verify.sh` -- add exit code 124 check, process group kill
- `lib/csv.sh` -- add TIMEOUT to valid outcomes in ledger_validate
- `analysis/compare.py` -- report TIMEOUT separately from FAIL
