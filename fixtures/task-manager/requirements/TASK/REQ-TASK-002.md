# REQ-TASK-002: Status State Machine

## Status: MISSING
## Priority: HIGH
## Phase: 2

## Requirement

Implement a status transition endpoint for tasks that enforces a state machine. Tasks have three statuses: TODO, IN_PROGRESS, and DONE. Only specific transitions are allowed. Invalid transitions must be rejected with a descriptive error.

## Acceptance Criteria

1. PUT /tasks/:id/status accepts a new status and transitions the task if the transition is valid.
2. The transition TODO -> IN_PROGRESS is allowed and succeeds with 200 OK.
3. The transition IN_PROGRESS -> DONE is allowed and succeeds with 200 OK.
4. The transition IN_PROGRESS -> TODO is allowed and succeeds with 200 OK.
5. The transition TODO -> DONE is rejected with 422 Unprocessable Entity.
6. Any transition from DONE (DONE -> TODO, DONE -> IN_PROGRESS) is rejected with 422 Unprocessable Entity.
7. The error response for invalid transitions includes the current status and attempted status.
8. The updated_at timestamp is refreshed on a successful status transition.
9. The endpoint returns 403 Forbidden if the authenticated user does not own the parent project.

## API Endpoints

### PUT /tasks/:id/status

**Request:**
```json
{
  "status": "IN_PROGRESS"
}
```

**Response (200 OK):**
```json
{
  "id": 1,
  "title": "Implement login",
  "status": "IN_PROGRESS",
  "project_id": 1,
  "updated_at": "2026-01-15T11:00:00Z"
}
```

**Error (422 Unprocessable Entity):**
```json
{
  "error": "invalid status transition from TODO to DONE"
}
```

## Dependencies

- REQ-TASK-001: Requires tasks to exist with a status field.
