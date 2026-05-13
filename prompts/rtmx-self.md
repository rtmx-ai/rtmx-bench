# Task: Implement Release Gate Command

Implement a `release gate` subcommand for this Go CLI project. The command
should verify that a tagged release is ready to ship by checking that all
requirements assigned to the target version are in COMPLETE status.

## Functional Requirements

1. `release gate <version>` checks all requirements assigned to the given
   version (via the `sprint` column in the CSV database)
2. If all assigned requirements have status COMPLETE, print a success
   message and exit 0
3. If any assigned requirements are not COMPLETE, print a table showing
   the incomplete requirements (ID, status, description) and exit 1
4. If no requirements are assigned to the version, print a warning and
   exit 1
5. The command should accept a `--json` flag for machine-readable output

## Non-Functional Requirements

- Follow the existing code patterns (Cobra commands, table output)
- Add unit tests covering all exit conditions
- The command must work with the existing CSV database format

## Success Criterion

All tests pass when running `go test ./...`
