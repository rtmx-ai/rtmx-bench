# REQ-EXP-002: Brownfield Experiment

## Status: MISSING
## Priority: HIGH
## Phase: 2

## Requirement

rtmx-bench shall include a brownfield experiment where an agent modifies
an existing unfamiliar codebase, measuring how structured requirements
affect navigation and task completion in code the agent has never seen.

## Rationale

Most real-world agent work is brownfield: adding features, fixing bugs,
and refactoring existing code. The brownfield experiment tests whether
RTMX requirements reduce the exploration overhead -- the tokens an agent
spends reading files, understanding architecture, and backtracking from
wrong assumptions before it can do productive work.

The project must be unfamiliar to the model. Using a well-known open
source project (e.g., Express, Flask) risks the model relying on
training data rather than actually navigating the code. We need a
project obscure enough that the agent must genuinely explore.

## Acceptance Criteria

1. Project: a real open-source project selected for:
   - Language: Go, Python, or TypeScript (well-supported by agents)
   - Size: 2,000-10,000 LOC (large enough to require navigation,
     small enough to complete tasks in one session)
   - Test suite: existing tests that pass on clone
   - Obscurity: fewer than 500 GitHub stars (reduces training data
     memorization risk)
   - License: permissive (MIT, Apache 2.0, BSD)
2. Three tasks of varying complexity:
   - Task A (small): fix a specific bug or add input validation
   - Task B (medium): add a new feature that touches 3-5 files
   - Task C (large): refactor a subsystem while maintaining test parity
3. Treatment condition includes a pre-built RTM covering all three
   tasks with acceptance criteria, affected files, and dependencies
4. Each task has an independent success criterion (specific tests)
5. Multi-task experiment: tasks are presented sequentially in one
   session to test the amortization hypothesis (does task C benefit
   from context built during tasks A and B?)
6. The project is pinned to a specific commit SHA for reproducibility

## Dependencies

- REQ-HARNESS-001: Experiment runner
- REQ-HARNESS-003: Prompt identity
- REQ-HARNESS-004: Outcome verification
- REQ-EXP-001: Greenfield experiment (validates harness before
  running the more complex brownfield experiment)

## Files to Create

- `prompts/brownfield.md` -- task prompt (all three tasks)
- `experiments/brownfield.yaml` -- experiment config with commit SHA
- `fixtures/brownfield/rtm.csv` -- treatment RTM database
- `fixtures/brownfield/requirements/` -- requirement specs
