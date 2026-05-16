# REQ-TEST-001: Comprehensive Test Suite

## Status: MISSING
## Priority: P0
## Phase: 3

## Requirement

Implement a comprehensive test suite that validates all API endpoints, state transitions, input validation, error handling, and authorization rules. The test suite must be self-contained (creating and tearing down its own test database), executable with a single command, and provide clear pass/fail output.

## Acceptance Criteria

1. A single command (e.g., `make test`, `npm test`, `pytest`, `go test ./...`) runs the entire test suite.
2. The test suite creates a fresh test database before running and tears it down after completion.
3. Tests do not depend on external services or pre-existing data.
4. All endpoints defined in REQ-AUTH-001 and REQ-AUTH-002 are covered (registration, login, middleware).
5. All endpoints defined in REQ-PROJ-001 are covered (project CRUD with ownership enforcement).
6. All endpoints defined in REQ-TASK-001 are covered (task CRUD with project scoping).
7. All status transitions defined in REQ-TASK-002 are covered (both valid and invalid).
8. Due date handling defined in REQ-TASK-003 is covered.
9. Label operations defined in REQ-LABEL-001 are covered (create, attach, detach, list).
10. Activity logging defined in REQ-LOG-001 is covered (auto-logging and query).
11. Overdue detection defined in REQ-BG-001 is covered.
12. All validation rules defined in REQ-VALID-001 are covered with invalid input cases.
13. All error codes defined in REQ-ERR-001 are covered (401, 403, 404, 409, 422).
14. The test command exits 0 when all tests pass.
15. The test command exits non-zero when any test fails.
16. Test output clearly identifies which tests passed and which failed.

## API Endpoints

Not applicable. This requirement covers testing of all other requirements' endpoints.

## Dependencies

- REQ-DB-001: Database setup.
- REQ-AUTH-001: User registration.
- REQ-AUTH-002: JWT login and middleware.
- REQ-PROJ-001: Project CRUD.
- REQ-TASK-001: Task CRUD.
- REQ-TASK-002: Status state machine.
- REQ-TASK-003: Due dates and overdue flag.
- REQ-LABEL-001: Labels and task-label association.
- REQ-LOG-001: Activity log.
- REQ-BG-001: Overdue detection.
- REQ-VALID-001: Input validation.
- REQ-ERR-001: Error responses.
