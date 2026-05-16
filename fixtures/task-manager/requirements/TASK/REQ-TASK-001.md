# REQ-TASK-001: Task CRUD

## Status: MISSING
## Priority: P0
## Phase: 2

## Requirement

Implement full CRUD operations for tasks within projects. Tasks belong to a project and are scoped to the project owner. Users may only create, view, update, and delete tasks in projects they own. All task endpoints require authentication.

## Acceptance Criteria

1. POST /projects/:id/tasks creates a new task in the specified project and returns 201 Created.
2. POST /projects/:id/tasks returns 403 Forbidden if the authenticated user does not own the project.
3. GET /projects/:id/tasks returns all tasks belonging to the specified project.
4. GET /projects/:id/tasks returns 403 Forbidden if the authenticated user does not own the project.
5. GET /tasks/:id returns the task if the authenticated user owns the parent project.
6. GET /tasks/:id returns 403 Forbidden if the authenticated user does not own the parent project.
7. GET /tasks/:id returns 404 Not Found if the task does not exist.
8. PUT /tasks/:id updates the task fields (title, description, assignee_id) if the user owns the parent project.
9. PUT /tasks/:id returns 403 Forbidden if the authenticated user does not own the parent project.
10. DELETE /tasks/:id deletes the task if the user owns the parent project.
11. DELETE /tasks/:id returns 403 Forbidden if the authenticated user does not own the parent project.
12. New tasks default to status "TODO".
13. The created_at and updated_at timestamps are set automatically on creation; updated_at is refreshed on update.

## API Endpoints

### POST /projects/:id/tasks

**Request:**
```json
{
  "title": "Implement login",
  "description": "Build the login endpoint",
  "assignee_id": 1
}
```

**Response (201 Created):**
```json
{
  "id": 1,
  "title": "Implement login",
  "description": "Build the login endpoint",
  "status": "TODO",
  "due_date": null,
  "is_overdue": false,
  "project_id": 1,
  "assignee_id": 1,
  "created_at": "2026-01-15T10:30:00Z",
  "updated_at": "2026-01-15T10:30:00Z"
}
```

### GET /projects/:id/tasks

**Response (200 OK):**
```json
[
  {
    "id": 1,
    "title": "Implement login",
    "description": "Build the login endpoint",
    "status": "TODO",
    "due_date": null,
    "is_overdue": false,
    "project_id": 1,
    "assignee_id": 1,
    "created_at": "2026-01-15T10:30:00Z",
    "updated_at": "2026-01-15T10:30:00Z"
  }
]
```

### GET /tasks/:id

**Response (200 OK):**
```json
{
  "id": 1,
  "title": "Implement login",
  "description": "Build the login endpoint",
  "status": "TODO",
  "due_date": null,
  "is_overdue": false,
  "project_id": 1,
  "assignee_id": 1,
  "created_at": "2026-01-15T10:30:00Z",
  "updated_at": "2026-01-15T10:30:00Z"
}
```

### PUT /tasks/:id

**Request:**
```json
{
  "title": "Implement login (updated)",
  "description": "Updated description"
}
```

**Response (200 OK):** (updated task object)

### DELETE /tasks/:id

**Response (204 No Content)**

## Dependencies

- REQ-PROJ-001: Tasks belong to projects; project ownership determines task access.
