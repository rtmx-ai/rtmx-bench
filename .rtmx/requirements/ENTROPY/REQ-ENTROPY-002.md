# REQ-ENTROPY-002: Staleness Score

## Status: MISSING
## Priority: P0
## Phase: 1

## Requirement

rtmx-bench shall compute a staleness score measuring how current each
intent-bearing file is relative to the code it describes, using git
history as the source of truth.

## Rationale

Stale documentation is worse than no documentation -- it provides
confident but wrong context. An agent that reads a 6-month-old
REQUIREMENTS.md in an actively developed repo will plan against
outdated assumptions, wasting tokens on work that's already done or
approaches that have been abandoned. Staleness is the gap between
when documentation was last updated and when the code around it
last changed.

## Acceptance Criteria

1. For each intent-bearing file discovered by REQ-ENTROPY-001,
   computes:
   - `file_age_days`: days since last modification (via git log)
   - `repo_activity_days`: days since most recent commit in the repo
   - `staleness_ratio`: file_age_days / max(repo_activity_days, 1)
2. A file with staleness_ratio > 3.0 is classified as STALE
   (intent file is 3x older than recent repo activity)
3. A file with staleness_ratio > 10.0 is classified as ABANDONED
4. Computes aggregate staleness_score:
   count(STALE + ABANDONED files) / count(all intent files)
5. For files not tracked by git, classifies as UNTRACKED and
   excludes from staleness computation (but reports them)
6. Reports per-file detail: path, last_modified, staleness_ratio,
   classification
7. Outputs structured JSON merged with scatter results

## Dependencies

- REQ-ENTROPY-001: Scatter score (provides the list of intent files)

## Files to Create

- `entropy/staleness.sh` -- git history analysis per intent file
