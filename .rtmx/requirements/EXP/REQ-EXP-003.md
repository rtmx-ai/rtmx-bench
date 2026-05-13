# REQ-EXP-003: Self-Referential Experiment

## Status: MISSING
## Priority: HIGH
## Phase: 3

## Requirement

rtmx-bench shall include a self-referential experiment using the RTMX
CLI codebase itself, enabling ground-truth comparison against historical
session data from actual development.

## Rationale

RTMX was built with RTMX. We have historical data: 234 completed
requirements, commit history showing implementation order, and (from
session transcripts) approximate token costs per requirement. This is
the only experiment where we have ground truth for the treatment
condition -- we can compare the control condition (agent works without
RTMX) against known actual costs with RTMX.

The self-referential experiment also tests the largest database size
(234 requirements) and the most complex dependency graph, stressing
the token efficiency of MCP tool responses at scale.

## Acceptance Criteria

1. Project: rtmx-ai/rtmx at a specific tagged release (e.g., v1.0.0)
2. Three tasks selected from actual historical requirements:
   - A simple task (< 0.5 effort_weeks in the RTM)
   - A medium task (0.5-1.0 effort_weeks)
   - A complex task (> 1.0 effort_weeks with dependencies)
3. Tasks are "replayed": the agent starts from the commit just before
   the requirement was implemented and attempts to implement it
4. Treatment condition: full RTM database as it existed at that commit
   (reconstructed from git history of .rtmx/database.csv)
5. Control condition: same starting commit, same task prompt, no RTM
6. Ground truth comparison: actual historical token cost (from session
   transcripts if available) vs. both experimental conditions
7. Tests pass against the same test suite that existed at the target
   commit (not current HEAD)
8. The experiment configuration documents which requirements were
   selected and why

## Dependencies

- REQ-HARNESS-001: Experiment runner
- REQ-HARNESS-003: Prompt identity
- REQ-HARNESS-004: Outcome verification
- REQ-EXP-001: Greenfield experiment (validates harness)
- REQ-EXP-002: Brownfield experiment (validates multi-task flow)

## Files to Create

- `prompts/rtmx-self.md` -- task prompts for selected requirements
- `experiments/rtmx-self.yaml` -- experiment config with commit SHAs
- `fixtures/rtmx-self/rtm.csv` -- RTM database at target commit
- `fixtures/rtmx-self/requirements/` -- requirement specs at target commit
