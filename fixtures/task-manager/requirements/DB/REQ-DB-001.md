# REQ-DB-001: Database Setup with SQLite

## Status: MISSING
## Priority: P0
## Phase: 1

## Requirement

Initialize a SQLite database with the complete schema for the task manager application. The schema must include tables for users, projects, tasks, labels, task-label associations, and an activity log. The database must support schema versioning to enable future migrations.

## Acceptance Criteria

1. A SQLite database file is created on application startup if it does not already exist.
2. The `users` table exists with columns: id (INTEGER PRIMARY KEY), username (TEXT UNIQUE NOT NULL), email (TEXT UNIQUE NOT NULL), password_hash (TEXT NOT NULL), created_at (TEXT NOT NULL).
3. The `projects` table exists with columns: id (INTEGER PRIMARY KEY), name (TEXT NOT NULL), description (TEXT), owner_id (INTEGER NOT NULL REFERENCES users(id)), created_at (TEXT NOT NULL), updated_at (TEXT NOT NULL).
4. The `tasks` table exists with columns: id (INTEGER PRIMARY KEY), title (TEXT NOT NULL), description (TEXT), status (TEXT NOT NULL DEFAULT 'TODO'), due_date (TEXT), is_overdue (INTEGER NOT NULL DEFAULT 0), project_id (INTEGER NOT NULL REFERENCES projects(id)), assignee_id (INTEGER REFERENCES users(id)), created_at (TEXT NOT NULL), updated_at (TEXT NOT NULL).
5. The `labels` table exists with columns: id (INTEGER PRIMARY KEY), name (TEXT UNIQUE NOT NULL), color (TEXT).
6. The `task_labels` table exists with columns: task_id (INTEGER NOT NULL REFERENCES tasks(id)), label_id (INTEGER NOT NULL REFERENCES labels(id)), PRIMARY KEY (task_id, label_id).
7. The `activity_log` table exists with columns: id (INTEGER PRIMARY KEY), timestamp (TEXT NOT NULL), user_id (INTEGER NOT NULL REFERENCES users(id)), action (TEXT NOT NULL), entity_type (TEXT NOT NULL), entity_id (INTEGER NOT NULL), details (TEXT).
8. Foreign key enforcement is enabled (PRAGMA foreign_keys = ON).
9. Indexes exist on: tasks(project_id), tasks(assignee_id), tasks(status), activity_log(entity_type, entity_id), task_labels(label_id).
10. A schema_version table tracks the current schema version number.

## API Endpoints

Not applicable. This is an internal infrastructure requirement.

## Dependencies

None. This is the foundational requirement.
