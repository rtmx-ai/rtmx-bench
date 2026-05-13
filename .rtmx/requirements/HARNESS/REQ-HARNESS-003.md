# REQ-HARNESS-003: Prompt Identity

## Status: MISSING
## Priority: P0
## Phase: 1

## Requirement

rtmx-bench shall enforce that control and treatment conditions receive
identical task prompts, with the prompt stored as a versioned artifact.

## Rationale

If the prompts differ between conditions, any observed token difference
could be attributed to prompt wording rather than RTMX. Prompt identity
is the most critical experimental control. The prompt must describe the
task without mentioning RTMX, requirements traceability, or MCP -- the
agent discovers those capabilities (or doesn't) from its environment.

## Acceptance Criteria

1. Task prompts are stored in `prompts/<experiment>.md` as plain
   markdown files, one per experiment
2. The prompt text contains no reference to RTMX, RTM, MCP, requirements
   database, or any tool that only exists in the treatment condition
3. The runner delivers the prompt identically to both conditions via
   `claude --prompt-file prompts/<experiment>.md`
4. The runner logs the SHA-256 hash of the prompt file in the summary
   CSV to detect unintentional prompt drift between runs
5. The prompt includes a clear success criterion that maps to a
   verifiable outcome (e.g., "all tests pass")
6. The prompt does not instruct the agent to use or avoid any specific
   tool -- tool selection is the agent's decision based on environment

## Dependencies

- REQ-HARNESS-001: Experiment runner (delivers the prompts)

## Files to Create

- `prompts/` directory
- Prompt files created per-experiment (REQ-EXP-001, 002, 003)
