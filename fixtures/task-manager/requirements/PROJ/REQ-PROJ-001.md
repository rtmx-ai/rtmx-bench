# REQ-PROJ-001: Project CRUD

## Status: MISSING
## Priority: P0
## Phase: 2

## Requirement

Implement full CRUD operations for projects. Projects are owned by the authenticated user who creates them. Users may only view, update, and delete their own projects. All project endpoints require authentication.

## Acceptance Criteria

1. POST /projects creates a new project owned by the authenticated user and returns 201 Created.
2. GET /projects returns only the projects owned by the authenticated user.
3. GET /projects/:id returns the project if the authenticated user is the owner.
4. GET /projects/:id returns 403 Forbidden if the authenticated user is not the owner.
5. GET /projects/:id returns 404 Not Found if the project does not exist.
6. PUT /projects/:id updates the project name and/or description if the authenticated user is the owner.
7. PUT /projects/:id returns 403 Forbidden if the authenticated user is not the owner.
8. DELETE /projects/:id deletes the project and all associated tasks if the authenticated user is the owner.
9. DELETE /projects/:id returns 403 Forbidden if the authenticated user is not the owner.
10. The created_at and updated_at timestamps are set automatically on creation; updated_at is refreshed on update.

## API Endpoints

### POST /projects

**Request:**
```json
{
  "name": "My Project",
  "description": "A sample project"
}
```

**Response (201 Created):**
```json
{
  "id": 1,
  "name": "My Project",
  "description": "A sample project",
  "owner_id": 1,
  "created_at": "2026-01-15T10:30:00Z",
  "updated_at": "2026-01-15T10:30:00Z"
}
```

### GET /projects

**Response (200 OK):**
```json
[
  {
    "id": 1,
    "name": "My Project",
    "description": "A sample project",
    "owner_id": 1,
    "created_at": "2026-01-15T10:30:00Z",
    "updated_at": "2026-01-15T10:30:00Z"
  }
]
```

### PUT /projects/:id

**Request:**
```json
{
  "name": "Updated Project Name",
  "description": "Updated description"
}
```

**Response (200 OK):**
```json
{
  "id": 1,
  "name": "Updated Project Name",
  "description": "Updated description",
  "owner_id": 1,
  "created_at": "2026-01-15T10:30:00Z",
  "updated_at": "2026-01-15T11:00:00Z"
}
```

### DELETE /projects/:id

**Response (204 No Content)**

**Error (403 Forbidden):**
```json
{
  "error": "not the project owner"
}
```

## Dependencies

- REQ-AUTH-002: Requires JWT authentication middleware to identify the current user.
