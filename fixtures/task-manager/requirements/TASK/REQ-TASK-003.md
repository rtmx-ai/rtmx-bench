# REQ-TASK-003: Due Dates and Overdue Flag

## Status: MISSING
## Priority: HIGH
## Phase: 2

## Requirement

Support due dates on tasks using ISO 8601 format. Each task has an is_overdue boolean flag that defaults to false. Due dates can be set at task creation or updated later. The is_overdue flag is managed by the overdue detection process (REQ-BG-001) and is not directly settable by the user.

## Acceptance Criteria

1. Tasks accept an optional due_date field in ISO 8601 format (e.g., "2026-02-01T00:00:00Z") at creation time.
2. The due_date field can be updated via PUT /tasks/:id.
3. The due_date field can be set to null to remove the due date.
4. The is_overdue field defaults to false when a task is created.
5. The is_overdue field is read-only in task creation and update requests (ignored if provided).
6. The is_overdue field is included in all task response objects.
7. Invalid date formats in due_date return 422 Unprocessable Entity.

## API Endpoints

### POST /projects/:id/tasks (with due date)

**Request:**
```json
{
  "title": "Write report",
  "due_date": "2026-02-01T00:00:00Z"
}
```

**Response (201 Created):**
```json
{
  "id": 2,
  "title": "Write report",
  "status": "TODO",
  "due_date": "2026-02-01T00:00:00Z",
  "is_overdue": false,
  "project_id": 1,
  "created_at": "2026-01-15T10:30:00Z",
  "updated_at": "2026-01-15T10:30:00Z"
}
```

### PUT /tasks/:id (update due date)

**Request:**
```json
{
  "due_date": "2026-03-01T00:00:00Z"
}
```

## Dependencies

- REQ-TASK-001: Requires task CRUD to exist so due_date and is_overdue fields can be managed.
