# REQ-BG-001: Overdue Detection

## Status: MISSING
## Priority: MEDIUM
## Phase: 3

## Requirement

Implement an endpoint that checks all tasks with due dates and flags those that are overdue. A task is considered overdue if its due_date is in the past and its status is not DONE. Tasks that are already DONE or have no due_date are never flagged as overdue.

## Acceptance Criteria

1. POST /tasks/check-overdue scans all tasks and updates the is_overdue flag accordingly.
2. Tasks with due_date < now() and status != "DONE" have is_overdue set to true.
3. Tasks with due_date >= now() have is_overdue set to false (clearing any previous overdue flag).
4. Tasks with status "DONE" have is_overdue set to false regardless of due_date.
5. Tasks with no due_date (null) have is_overdue set to false.
6. The endpoint returns 200 OK with a summary of how many tasks were flagged as overdue.
7. The endpoint requires authentication.

## API Endpoints

### POST /tasks/check-overdue

**Response (200 OK):**
```json
{
  "checked": 15,
  "overdue": 3,
  "cleared": 2
}
```

Where:
- `checked` is the total number of tasks examined.
- `overdue` is the number of tasks newly or still flagged as overdue.
- `cleared` is the number of tasks that had is_overdue cleared (due date moved or task completed).

## Dependencies

- REQ-TASK-003: Requires due_date and is_overdue fields on tasks.
