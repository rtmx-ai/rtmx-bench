# REQ-LOG-001: Activity Log

## Status: MISSING
## Priority: HIGH
## Phase: 2

## Requirement

Implement an append-only activity log that automatically records all mutations (create, update, delete) across all entities. The log captures who performed the action, what was changed, and when. Activity is queryable per project.

## Acceptance Criteria

1. Every create, update, or delete operation on projects, tasks, and labels automatically creates an activity_log entry.
2. Each log entry records: timestamp (ISO 8601), user_id, action ("create", "update", or "delete"), entity_type ("project", "task", or "label"), entity_id, and details (JSON string describing the change).
3. GET /projects/:id/activity returns all activity log entries related to the specified project, ordered by timestamp descending.
4. GET /projects/:id/activity returns 403 Forbidden if the authenticated user does not own the project.
5. Activity entries for tasks include the parent project_id so they appear in the project activity feed.
6. The activity log is append-only; there is no endpoint to update or delete log entries.
7. The details field contains a JSON object with relevant change information (e.g., old and new values for updates).

## API Endpoints

### GET /projects/:id/activity

**Response (200 OK):**
```json
[
  {
    "id": 3,
    "timestamp": "2026-01-15T11:00:00Z",
    "user_id": 1,
    "action": "update",
    "entity_type": "task",
    "entity_id": 1,
    "details": "{\"field\": \"status\", \"old\": \"TODO\", \"new\": \"IN_PROGRESS\"}"
  },
  {
    "id": 2,
    "timestamp": "2026-01-15T10:30:00Z",
    "user_id": 1,
    "action": "create",
    "entity_type": "task",
    "entity_id": 1,
    "details": "{\"title\": \"Implement login\"}"
  },
  {
    "id": 1,
    "timestamp": "2026-01-15T10:00:00Z",
    "user_id": 1,
    "action": "create",
    "entity_type": "project",
    "entity_id": 1,
    "details": "{\"name\": \"My Project\"}"
  }
]
```

**Error (403 Forbidden):**
```json
{
  "error": "not the project owner"
}
```

## Dependencies

- REQ-AUTH-002: Requires authentication to identify the user performing the action and to enforce project ownership on the query endpoint.
