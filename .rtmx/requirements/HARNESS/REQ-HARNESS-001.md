# REQ-HARNESS-001: Experiment Runner

## Status: MISSING
## Priority: P0
## Phase: 1

## Requirement

rtmx-bench shall provide a shell-based experiment runner that executes
controlled A/B sessions comparing agent task completion with and without
RTMX requirements traceability.

## Rationale

The central claim of RTMX is that structured requirements reduce total
agent token consumption per completed task. Testing this claim requires
a controlled experiment where the only variable is the presence or
absence of an RTM database and MCP tools. The runner must automate
session setup, execution, and data capture so experiments are repeatable
and not dependent on manual operator steps.

## Acceptance Criteria

1. `bench.sh run <experiment> --condition control|treatment --runs N`
   executes N independent agent sessions for the specified condition
2. Control condition: clones the project, delivers the task prompt,
   no RTMX artifacts or MCP tools present
3. Treatment condition: clones the project, seeds with pre-built RTM
   database from `fixtures/<experiment>/rtm.csv`, configures MCP, then
   delivers the identical task prompt
4. Each run uses a clean clone (no state leakage between runs)
5. Runner captures: session transcript, token counts, test results,
   wall-clock time, exit status
6. All captured data is written to `results/raw/<experiment>/<condition>/<run_id>/`
7. Runner produces one row per run in `results/summary.csv`
8. Runner exits non-zero if any infrastructure failure occurs (clone
   failure, model API error) but NOT for agent task failure (that's data)
9. Runner supports `--model` flag to specify the Claude model
   (default: claude-sonnet-4-20250514)
10. Runner supports `--dry-run` to validate experiment setup without
    invoking the model

## Dependencies

None (foundation requirement)

## Files to Create

- `bench.sh` -- main experiment runner
- `lib/setup.sh` -- project clone and RTMX seeding helpers
- `lib/capture.sh` -- transcript and token extraction
- `lib/csv.sh` -- ledger row construction
