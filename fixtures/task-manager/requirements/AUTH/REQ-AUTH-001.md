# REQ-AUTH-001: User Registration

## Status: MISSING
## Priority: P0
## Phase: 1

## Requirement

Implement a user registration endpoint that creates new user accounts. Passwords must be securely hashed using bcrypt or argon2 before storage. The system must reject duplicate email addresses and enforce input validation on all registration fields.

## Acceptance Criteria

1. POST /auth/register creates a new user and returns the user record (without password_hash).
2. The password is hashed with bcrypt or argon2 before being stored in the database.
3. The plaintext password is never stored in the database or returned in any response.
4. Attempting to register with a duplicate email returns 409 Conflict.
5. Attempting to register with a duplicate username returns 409 Conflict.
6. A successful registration returns 201 Created with the user's id, username, and email.
7. The created_at timestamp is set automatically at registration time.

## API Endpoints

### POST /auth/register

**Request:**
```json
{
  "username": "alice",
  "email": "alice@example.com",
  "password": "securepassword123"
}
```

**Response (201 Created):**
```json
{
  "id": 1,
  "username": "alice",
  "email": "alice@example.com",
  "created_at": "2026-01-15T10:30:00Z"
}
```

**Error (409 Conflict):**
```json
{
  "error": "email already registered"
}
```

## Dependencies

- REQ-DB-001: Requires the users table to exist.
