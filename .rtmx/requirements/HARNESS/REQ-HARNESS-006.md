# REQ-HARNESS-006: Process Isolation

## Status: MISSING
## Priority: P0
## Phase: 1

## Requirement

rtmx-bench shall isolate each agent session in its own process group
and guarantee cleanup of all child processes when a run completes or
is interrupted.

## Rationale

Agents spawn long-running subprocesses (HTTP servers, test watchers,
background jobs) that outlive the parent Claude Code process. Without
process group isolation, these orphans consume ports and resources,
causing cascading failures in subsequent runs. This was observed in
production: treatment runs spawned HTTP servers on port 8080 that
persisted across runs, causing EADDRINUSE errors.

## Acceptance Criteria

1. The Claude Code subprocess runs in its own process group (via
   setsid or equivalent on macOS)
2. When a run completes (success or failure), all processes in the
   group are terminated
3. When bench.sh receives SIGINT or SIGTERM, all child process
   groups are cleaned up before exit
4. A `trap EXIT` handler ensures cleanup even on unexpected errors
5. Temporary working directories are removed on both normal exit
   and signal interruption
6. The cleanup function is idempotent (safe to call multiple times)

## Dependencies

- REQ-HARNESS-001: Experiment runner (provides the subprocess to isolate)

## Files to Modify

- `bench.sh` -- add setsid wrapper, trap handlers, cleanup function
