# REQ-HARNESS-002: Token Accounting

## Status: MISSING
## Priority: P0
## Phase: 1

## Requirement

rtmx-bench shall extract per-session token counts from agent transcripts,
attributing tokens to RTMX tool calls versus all other agent activity.

## Rationale

Total token count alone is insufficient. The experiment must distinguish
between tokens spent on RTMX context (MCP tool responses injected into
the prompt) and tokens spent on everything else (code reading, reasoning,
editing). This decomposition reveals whether RTMX adds net token cost
or displaces more expensive unstructured exploration.

## Acceptance Criteria

1. Extracts input_tokens and output_tokens from Claude Code session
   output (via `--output-format json` or transcript parsing)
2. Identifies MCP tool calls in the transcript by tool name and
   computes rtmx_tokens as the sum of all RTMX tool response sizes
3. Computes non_rtmx_tokens = input_tokens - rtmx_tokens
4. Computes planning_tokens: tokens spent on RTMX tool calls that
   occur before the first code edit (requirements discovery phase)
5. Computes execution_tokens: tokens spent after the first code edit
6. All token counts are integers (no fractional tokens)
7. Token attribution is logged per-tool: which MCP tools were called,
   how many times, and how many tokens each contributed
8. If the transcript format changes across Claude Code versions,
   the parser fails loudly rather than producing wrong counts

## Dependencies

- REQ-HARNESS-001: Experiment runner (produces the transcripts to parse)

## Files to Create

- `lib/tokens.sh` -- token extraction and attribution logic
- `lib/parse_transcript.py` -- Python parser for structured transcript
  analysis (shell is insufficient for JSON parsing at this granularity)
