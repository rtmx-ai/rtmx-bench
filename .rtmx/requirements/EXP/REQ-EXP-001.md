# REQ-EXP-001: Greenfield Experiment

## Status: MISSING
## Priority: P0
## Phase: 2

## Requirement

rtmx-bench shall include a greenfield experiment where an agent builds
a complete application from an empty repository, measuring the token
cost of both planning and execution from zero.

## Rationale

Greenfield projects isolate the planning overhead question: when there's
no existing code to navigate, is the upfront cost of building an RTM
database offset by more focused execution? This is the hardest case for
RTMX -- in an empty repo, there's nothing to navigate, so the control
condition pays no "exploration tax." If RTMX still wins here, the
planning-pays-for-itself hypothesis is strongly supported.

## Acceptance Criteria

1. Project: URL shortener with the following scope:
   - HTTP API: POST /shorten (create), GET /:code (redirect), GET /stats/:code
   - Persistent storage (SQLite or file-based)
   - Rate limiting (10 requests/minute per IP)
   - Input validation (valid URLs only)
   - Test suite covering all endpoints
2. Prompt describes the functional requirements in plain English
   without prescribing architecture, language, or framework
3. Treatment condition includes a pre-built RTM with 8-12 requirements
   covering the scope above, with acceptance criteria and dependency
   ordering (e.g., storage before API, API before rate limiting)
4. Success criterion: all tests pass, all endpoints functional
5. Fixture includes:
   - `fixtures/url-shortener/rtm.csv` -- pre-built RTM database
   - `fixtures/url-shortener/requirements/` -- requirement specs
6. The prompt is language-agnostic -- the agent chooses the language
7. The experiment is configured in `experiments/url-shortener.yaml`
   with `test_command`, `setup_command`, and project metadata

## Dependencies

- REQ-HARNESS-001: Experiment runner
- REQ-HARNESS-003: Prompt identity
- REQ-HARNESS-004: Outcome verification

## Files to Create

- `prompts/url-shortener.md` -- task prompt
- `experiments/url-shortener.yaml` -- experiment configuration
- `fixtures/url-shortener/rtm.csv` -- treatment RTM database
- `fixtures/url-shortener/requirements/` -- requirement specs
