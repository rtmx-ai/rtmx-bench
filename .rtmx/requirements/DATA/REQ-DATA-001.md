# REQ-DATA-001: CSV Ledger Format

## Status: MISSING
## Priority: P0
## Phase: 1

## Requirement

rtmx-bench shall define and enforce a structured CSV ledger format for
recording all experiment run data, serving as the single source of truth
for analysis.

## Rationale

Every analysis tool, visualization, and statistical test reads from
the same CSV. If the format is ambiguous or inconsistently populated,
downstream analysis breaks silently. Defining the schema as a
requirement ensures all harness components agree on column names,
types, and semantics.

## Acceptance Criteria

1. Ledger file: `results/summary.csv`
2. Column schema (in order):
   ```
   session_id          -- UUID, unique per run
   timestamp           -- ISO 8601, UTC
   experiment          -- experiment name (e.g., url-shortener)
   condition           -- control | treatment
   run_number          -- integer, 1-indexed within condition
   model               -- model identifier (e.g., claude-sonnet-4-20250514)
   prompt_sha256       -- SHA-256 of the prompt file
   input_tokens        -- integer, total input tokens
   output_tokens       -- integer, total output tokens
   total_tokens        -- integer, input + output
   rtmx_tokens         -- integer, tokens from MCP tool responses (0 for control)
   planning_tokens     -- integer, tokens before first code edit
   execution_tokens    -- integer, tokens after first code edit
   turns               -- integer, number of model invocations
   backtracks          -- integer, file re-reads and reverted edits
   tool_calls_rtmx     -- integer, number of RTMX MCP tool calls
   tool_calls_other    -- integer, number of non-RTMX tool calls
   outcome             -- PASS | PARTIAL | FAIL | ERROR
   tests_total         -- integer, total test count
   tests_passed        -- integer, passed test count
   tests_failed        -- integer, failed test count
   wall_clock_seconds  -- float, elapsed wall-clock time
   knowledge_entropy   -- float, entropy score of project (if computed)
   transcript_path     -- relative path to session transcript
   ```
3. The header row is always present, even in an empty ledger
4. The runner appends rows atomically (no partial writes on crash)
5. A `validate-ledger` subcommand checks that summary.csv conforms
   to the schema: correct column count, valid types, no empty
   required fields
6. The ledger is append-only -- runs are never overwritten or deleted
7. The schema is documented in `docs/ledger-schema.md`

## Dependencies

None (data format definition -- no code dependency)

## Files to Create

- `docs/ledger-schema.md` -- schema documentation
- `lib/csv.sh` -- ledger write and validation functions
