# REQ-HARNESS-008: Inter-Run Isolation

## Status: MISSING
## Priority: P0
## Phase: 1

## Requirement

rtmx-bench shall verify environment cleanliness before each run and
clean up orphaned processes between runs to prevent cascading failures.

## Rationale

Benchmark runs spawn HTTP servers and test processes that may not exit
cleanly. If a previous run's server still binds port 8080, the next
run's agent encounters EADDRINUSE errors that look like agent failures
but are actually harness failures. Pre-flight checks catch this before
wasting tokens on a doomed run.

## Acceptance Criteria

1. Before each run, check that common service ports (8080, 3000, 5000)
   are not occupied by processes from a previous bench run
2. If an occupied port is detected, warn and attempt to kill the
   orphan process before proceeding
3. Between runs in a batch, kill any processes whose working directory
   matches the previous run's temp directory pattern
4. The Makefile provides a `clean-processes` target to manually kill
   orphaned benchmark processes
5. Pre-flight failures are logged but do not prevent the run (the
   port may be legitimately in use by another service)

## Dependencies

- REQ-HARNESS-006: Process isolation (provides cleanup primitives)

## Files to Modify

- `bench.sh` -- add pre-flight checks and inter-run cleanup
- `Makefile` -- add clean-processes target
