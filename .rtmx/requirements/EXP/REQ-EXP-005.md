# REQ-EXP-005: Treatment Workflow Optimization

## Summary

The treatment condition CLAUDE.md workflow must enable closed-loop
verification by instructing the agent to use `rtmx verify --command`
(the CLI) instead of the MCP verify tool, which is read-only and does
not execute tests or update requirements.

## Motivation

In 10 treatment runs across two experiments:
- Every treatment run called mcp__rtmx__verify, which returned "0 complete"
  in all cases because the MCP verify tool only reads current database
  status -- it does not run tests or update requirements.
- Agents spent 30-40% of remaining tokens in verify retry loops trying
  to get the tool to acknowledge their passing tests.
- Treatment had 3 FAILs vs 0 in control, partly because verify loops
  consumed budget that would otherwise go toward fixing bugs.

The per-requirement claim-implement cycle is correct -- requirements
are discrete batches of work ordered by dependency. The fix is to
direct the agent to the CLI verify command that actually runs tests
and updates the database.

## Acceptance Criteria

1. bench.sh delegates CLAUDE.md generation to `rtmx install --agents claude`
   so the treatment condition uses the same prompt rtmx ships.

2. The rtmx-generated CLAUDE.md includes `rtmx verify --command` with
   `--update` flag for closed-loop verification.

3. The rtmx-generated CLAUDE.md shows verify command syntax for common
   languages (Node.js, Python, Go, Rust).

4. The workflow keeps the per-requirement claim-implement-verify cycle
   with dependency ordering via `next` and `backlog`.

## Files to Modify

- bench.sh -- replace CLAUDE.md template with `rtmx install` call
- rtmx (upstream) -- standardize agent prompts with workflow and verify guidance

## Dependencies

- REQ-EXP-001 (greenfield experiment)
- REQ-EXP-004 (complex experiment)
