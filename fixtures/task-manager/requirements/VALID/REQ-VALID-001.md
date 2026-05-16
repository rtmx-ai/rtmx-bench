# REQ-VALID-001: Input Validation

## Status: MISSING
## Priority: HIGH
## Phase: 2

## Requirement

All API endpoints must validate input data and return 422 Unprocessable Entity with descriptive error messages for invalid input. Validation rules cover email format, username constraints, non-empty required fields, and date format validation.

## Acceptance Criteria

1. Email fields must match a valid email format (contains @ and a domain); invalid emails return 422.
2. Username must be 3-30 characters and contain only alphanumeric characters and underscores; violations return 422.
3. Password must be at least 8 characters; shorter passwords return 422.
4. Project name must be non-empty; an empty or missing name returns 422.
5. Task title must be non-empty; an empty or missing title returns 422.
6. Label name must be non-empty; an empty or missing name returns 422.
7. Due dates must be valid ISO 8601 format; invalid dates return 422.
8. Status values must be one of: "TODO", "IN_PROGRESS", "DONE"; other values return 422.
9. All 422 responses include a descriptive error message identifying which field failed validation and why.
10. Validation errors are returned before any database operations are attempted.

## API Endpoints

Applies to all endpoints that accept input. Example error response:

**Error (422 Unprocessable Entity):**
```json
{
  "error": "username must be 3-30 alphanumeric characters"
}
```

```json
{
  "error": "invalid email format"
}
```

```json
{
  "error": "due_date must be in ISO 8601 format"
}
```

## Dependencies

- REQ-DB-001: Validation rules align with the database schema constraints.
