# REQ-ERR-001: Error Responses

## Status: MISSING
## Priority: HIGH
## Phase: 2

## Requirement

All API errors must use a consistent JSON format and appropriate HTTP status codes. The application must handle authentication errors, authorization errors, not-found errors, and validation errors uniformly across all endpoints.

## Acceptance Criteria

1. All error responses use the format: {"error": "descriptive message"}.
2. 401 Unauthorized is returned when the Authorization header is missing, the JWT is invalid, or the JWT is expired.
3. 403 Forbidden is returned when the authenticated user attempts to access or modify a resource they do not own.
4. 404 Not Found is returned when a requested resource (project, task, label) does not exist.
5. 409 Conflict is returned when a uniqueness constraint is violated (duplicate email, duplicate username, duplicate label name, duplicate task-label association).
6. 422 Unprocessable Entity is returned when input validation fails or an invalid state transition is attempted.
7. Error messages are descriptive enough to identify the problem without exposing internal implementation details.
8. No stack traces or internal paths are leaked in error responses.

## API Endpoints

Applies to all endpoints. Example responses:

**401 Unauthorized:**
```json
{
  "error": "missing or invalid authentication token"
}
```

**403 Forbidden:**
```json
{
  "error": "not the project owner"
}
```

**404 Not Found:**
```json
{
  "error": "task not found"
}
```

**422 Unprocessable Entity:**
```json
{
  "error": "invalid status transition from TODO to DONE"
}
```

## Dependencies

- REQ-DB-001: Error handling depends on database operations that may trigger not-found or constraint violations.
