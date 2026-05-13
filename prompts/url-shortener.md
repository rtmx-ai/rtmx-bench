# Task: Build a URL Shortener

Build a complete URL shortener service from scratch in this empty project directory.

## Functional Requirements

1. **HTTP API** with the following endpoints:
   - `POST /shorten` -- accepts a JSON body `{"url": "https://example.com"}` and returns `{"short_code": "abc123", "short_url": "http://localhost:8080/abc123"}`
   - `GET /:code` -- redirects to the original URL (HTTP 301)
   - `GET /stats/:code` -- returns JSON with click count: `{"short_code": "abc123", "url": "https://...", "clicks": 42}`

2. **Persistent storage** -- short URLs must survive process restart. Use SQLite or file-based storage (no external database required).

3. **Short code generation** -- codes must be 6-8 alphanumeric characters, unique, and URL-safe.

4. **Input validation**:
   - Reject non-URL input (return HTTP 400)
   - Reject empty body (return HTTP 400)
   - Return HTTP 404 for unknown short codes

5. **Rate limiting** -- limit to 10 requests per minute per IP address on the POST endpoint. Return HTTP 429 when exceeded.

## Non-Functional Requirements

- Choose any programming language and framework you prefer
- The service should listen on port 8080 by default
- Include a comprehensive test suite that covers all endpoints and edge cases
- Tests must be runnable with a single command

## Success Criterion

All tests pass when the test command is run.
