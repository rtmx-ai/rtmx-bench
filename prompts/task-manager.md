# Task Manager API

Build a task management REST API with the following capabilities.

## Requirements

### Database

- Use SQLite for persistent storage
- Create all necessary tables with proper schema
- Support schema versioning or migrations

### Authentication

- POST /auth/register -- register a new user (username, email, password)
- POST /auth/login -- authenticate and receive a JWT token
- All endpoints below require a valid JWT in the Authorization header
- Passwords must be hashed (never stored in plaintext)

### Projects

- POST /projects -- create a project (name, description)
- GET /projects -- list projects owned by the authenticated user
- GET /projects/:id -- get project details
- PUT /projects/:id -- update project (owner only)
- DELETE /projects/:id -- delete project and all associated tasks (owner only)

### Tasks

- POST /projects/:id/tasks -- create a task (title, description, due_date)
- GET /projects/:id/tasks -- list tasks in a project
- GET /tasks/:id -- get task details
- PUT /tasks/:id -- update task fields
- DELETE /tasks/:id -- delete task (project owner only)

#### Status State Machine

Tasks have a status field with these valid transitions:

    TODO -> IN_PROGRESS
    IN_PROGRESS -> DONE
    IN_PROGRESS -> TODO (revert)
    DONE -> (terminal, no transitions allowed)

PUT /tasks/:id/status with {"status": "IN_PROGRESS"} to transition.
Return 422 if the transition is invalid.

### Labels

- POST /labels -- create a label (name, color)
- GET /labels -- list all labels
- POST /tasks/:id/labels -- attach a label to a task
- DELETE /tasks/:id/labels/:label_id -- detach a label from a task
- GET /tasks/:id/labels -- list labels on a task

### Activity Log

- Every mutation (create, update, delete) on projects, tasks, and
  labels automatically records an entry in an append-only activity log
- GET /projects/:id/activity -- list activity for a project
- Each entry includes: timestamp, user, action, entity_type, entity_id, details

### Background Job: Overdue Detection

- Tasks with a due_date in the past and status != DONE should be
  flagged as overdue
- Provide an endpoint or mechanism to check and flag overdue tasks:
  POST /tasks/check-overdue
- This should update an is_overdue boolean field on affected tasks

### Input Validation

- All endpoints validate input and return 422 with descriptive errors
  for invalid requests
- Email must be valid format
- Username must be 3-30 alphanumeric characters
- Project and task names must not be empty
- Due dates must be valid ISO 8601 format

### Error Responses

- 401 for missing or invalid JWT
- 403 for operations on resources the user does not own
- 404 for resources that do not exist
- 422 for validation errors

## Technical Constraints

- The service should listen on port 8080 by default
- You may use any programming language and framework
- Include a comprehensive test suite that can be run with a single command
- Tests should cover all endpoints, status transitions, validation,
  and error cases
- The test suite should be self-contained (set up and tear down its
  own test database)
