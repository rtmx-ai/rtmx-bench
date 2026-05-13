# REQ-HARNESS-004: Outcome Verification

## Status: MISSING
## Priority: P0
## Phase: 1

## Requirement

rtmx-bench shall independently verify task outcomes by running the
project's test suite after each agent session, recording pass/fail
and test counts separately from the agent's self-reported status.

## Rationale

Agents may claim completion without actually finishing. Token efficiency
is only meaningful for completed tasks -- spending fewer tokens to
produce a broken result is not an improvement. Independent verification
ensures we compare like with like: tokens per *successful* completion.

## Acceptance Criteria

1. After each agent session, the runner executes the project's test
   command (specified in `experiments/<experiment>.yaml` as `test_command`)
2. Test results are captured: total tests, passed, failed, exit code
3. Task outcome is classified as:
   - PASS: all tests pass (exit 0)
   - PARTIAL: some tests pass but not all
   - FAIL: no tests pass or build fails
   - ERROR: infrastructure failure (not the agent's fault)
4. Outcome is recorded in summary.csv independently of what the
   agent reported in its final message
5. The test command runs in the same working directory the agent
   operated in, with the agent's changes in place
6. Test output is captured to
   `results/raw/<experiment>/<condition>/<run_id>/test_output.txt`
7. If the project has no test command defined, the experiment
   configuration is rejected at setup time (fail fast)

## Dependencies

- REQ-HARNESS-001: Experiment runner (orchestrates the verification step)

## Files to Create

- `lib/verify.sh` -- test execution and outcome classification
