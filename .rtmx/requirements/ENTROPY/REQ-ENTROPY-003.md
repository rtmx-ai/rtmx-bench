# REQ-ENTROPY-003: Navigability Score

## Status: MISSING
## Priority: HIGH
## Phase: 2

## Requirement

rtmx-bench shall compute a navigability score estimating how many file
reads an agent requires to answer canonical project questions, measured
empirically by running lightweight probe sessions.

## Rationale

Scatter and staleness measure static properties of knowledge artifacts.
Navigability measures the dynamic cost: given a question like "what
should I work on next?" or "what is the auth architecture?", how many
files does an agent actually read before producing an answer? This
directly maps to token cost -- each file read consumes tokens.

In a project with RTMX, "what should I work on next?" is answered by
one MCP call (next --one, 38 tokens). In a scattered project, the
agent may read README, TODO, REQUIREMENTS, 3 issue files, and 2 source
files before synthesizing an answer.

## Acceptance Criteria

1. Defines a set of 5 canonical project questions:
   - "What should I work on next?"
   - "What is the current project status?"
   - "What are the dependencies for feature X?"
   - "What tests exist and what do they cover?"
   - "What is the architecture of this project?"
2. For each question, runs a probe session: a short Claude Code
   invocation with the question as the prompt, recording which files
   the agent reads (tool calls) before answering
3. Computes navigability_score per question = number of file read
   operations before the agent's first answer
4. Computes aggregate navigability_score = mean across all questions
5. Runs probes on both control (no RTMX) and treatment (with RTMX)
   conditions to measure the navigability delta
6. Probe sessions are capped at 60 seconds and 10,000 tokens to
   bound cost
7. Outputs structured JSON: per-question read counts, files accessed,
   tokens consumed

## Dependencies

- REQ-ENTROPY-001: Scatter score (identifies the files the agent might read)
- REQ-HARNESS-001: Experiment runner (provides session infrastructure)
- REQ-HARNESS-002: Token accounting (counts tokens in probe sessions)

## Files to Create

- `entropy/navigability.sh` -- probe session runner
- `entropy/questions.txt` -- canonical question set
