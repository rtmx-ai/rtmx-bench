# REQ-EXP-004: Complex Multi-Requirement Experiment

## Status: MISSING
## Priority: HIGH
## Phase: 2

## Requirement

rtmx-bench shall include a complex experiment with a deep dependency
graph (5+ levels) and multiple entities, designed to expose the
difference between structured and unstructured agent approaches.

## Rationale

The url-shortener experiment (REQ-EXP-001) has ~5 requirements and
produces a single-file application. This is too simple to differentiate
control from treatment: an unstructured agent can brute-force it without
backtracking. RTMX's value proposition is reducing wasted exploration
on complex projects where the agent must discover the right build order
through trial and error. A deeper dependency graph forces ordering
decisions where RTMX's `mcp__rtmx__next` provides a direct advantage.

## Acceptance Criteria

1. Experiment name: `task-manager`
2. Prompt describes a multi-entity task management API:
   - User authentication (JWT register/login)
   - Projects (CRUD, owner-scoped)
   - Tasks (CRUD, project-scoped, status state machine)
   - Labels and task-label associations (many-to-many)
   - Activity log (append-only audit trail)
   - Background overdue task detection
   - Persistent storage (SQLite)
   - Comprehensive test suite
3. Fixture RTM contains 15+ requirements with a dependency graph
   at least 5 levels deep (DB -> Auth -> Projects -> Tasks -> Labels)
4. Prompt is language-agnostic (agent chooses language/framework)
5. Prompt contains NO RTMX/RTM/MCP references (experimental control)
6. Treatment fixture includes detailed requirement specs with
   acceptance criteria, API endpoint definitions, and test expectations
7. `bench.sh validate task-manager` passes
8. Budget ceiling: $10 per run (--max-budget-usd 10.00)

## Dependencies

- REQ-HARNESS-001: Experiment runner
- REQ-HARNESS-003: Prompt identity (no RTMX in prompt)
- REQ-HARNESS-004: Outcome verification

## Files to Create

- `experiments/task-manager.yaml` -- experiment configuration
- `prompts/task-manager.md` -- task prompt (no RTMX references)
- `fixtures/task-manager/rtm.csv` -- treatment RTM database
- `fixtures/task-manager/requirements/` -- requirement spec files
