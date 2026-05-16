# REQ-LABEL-001: Labels and Task-Label Association

## Status: MISSING
## Priority: HIGH
## Phase: 3

## Requirement

Implement labels that can be attached to tasks in a many-to-many relationship via the task_labels junction table. Labels are global (not project-scoped). Users can create labels, attach them to tasks, detach them from tasks, and list labels on a given task.

## Acceptance Criteria

1. POST /labels creates a new label with a name and optional color, returning 201 Created.
2. POST /labels with a duplicate name returns 409 Conflict.
3. GET /labels returns all labels.
4. POST /tasks/:id/labels attaches an existing label to a task, returning 201 Created.
5. POST /tasks/:id/labels with an already-attached label returns 409 Conflict.
6. DELETE /tasks/:id/labels/:label_id detaches a label from a task, returning 204 No Content.
7. DELETE /tasks/:id/labels/:label_id returns 404 Not Found if the label is not attached to the task.
8. GET /tasks/:id/labels returns all labels attached to the specified task.
9. Label operations on tasks require ownership of the parent project (403 Forbidden otherwise).

## API Endpoints

### POST /labels

**Request:**
```json
{
  "name": "urgent",
  "color": "#ff0000"
}
```

**Response (201 Created):**
```json
{
  "id": 1,
  "name": "urgent",
  "color": "#ff0000"
}
```

### GET /labels

**Response (200 OK):**
```json
[
  {"id": 1, "name": "urgent", "color": "#ff0000"},
  {"id": 2, "name": "bug", "color": "#cc0000"}
]
```

### POST /tasks/:id/labels

**Request:**
```json
{
  "label_id": 1
}
```

**Response (201 Created):**
```json
{
  "task_id": 1,
  "label_id": 1
}
```

### DELETE /tasks/:id/labels/:label_id

**Response (204 No Content)**

### GET /tasks/:id/labels

**Response (200 OK):**
```json
[
  {"id": 1, "name": "urgent", "color": "#ff0000"}
]
```

## Dependencies

- REQ-TASK-001: Requires tasks to exist so labels can be attached to them.
