# REQ-ENTROPY-001: Scatter Score

## Status: MISSING
## Priority: P0
## Phase: 1

## Requirement

rtmx-bench shall compute a scatter score measuring how many distinct
files and directories in a repository contain project intent (requirements,
plans, todos, roadmaps, task definitions).

## Rationale

When project intent is spread across many files, an agent (or human)
must discover and read all of them to build a complete picture. Each
additional file is a potential source of contradiction, staleness, and
wasted read tokens. Scatter is the most fundamental dimension of
knowledge entropy -- if everything is in one place, the other dimensions
matter less.

## Acceptance Criteria

1. `entropy scan <repo_path>` discovers intent-bearing files by matching
   known filename patterns:
   - `*README*`, `*TODO*`, `*REQUIREMENT*`, `*ROADMAP*`, `*PLAN*`,
     `*BACKLOG*`, `*CHANGELOG*`, `*ARCHITECTURE*`, `*DESIGN*`, `*ADR*`
   - `CLAUDE.md`, `AGENTS.md`, `COPILOT.md`, `CURSOR.md`
   - `.github/ISSUE_TEMPLATE/*`, `.github/PULL_REQUEST_TEMPLATE*`
   - `docs/**/*.md` (markdown in docs directories)
2. Also discovers inline intent markers by scanning source files for:
   - `TODO`, `FIXME`, `HACK`, `XXX` comments (count, not content)
3. Computes scatter_score = number of distinct intent-bearing files
4. Computes scatter_depth = number of distinct directories containing
   intent-bearing files
5. Reports a list of discovered files with their sizes and last
   modification dates
6. Outputs structured JSON: `{"scatter_score": N, "scatter_depth": N,
   "inline_markers": N, "files": [...]}`
7. Runs without network access, LLM calls, or project-specific
   configuration -- pure filesystem and git operations

## Dependencies

None (foundation requirement)

## Files to Create

- `entropy/scan.sh` -- file discovery and scoring
- `entropy/patterns.txt` -- configurable filename patterns
