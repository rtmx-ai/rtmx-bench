# Ledger Schema

The experiment data ledger (`results/summary.csv`) is the single source of truth
for all analysis. Every experiment run appends exactly one row.

## Columns

| Column | Type | Required | Description |
|--------|------|----------|-------------|
| session_id | UUID | yes | Unique identifier per run |
| timestamp | ISO 8601 | yes | UTC time when run started |
| experiment | string | yes | Experiment name (e.g., url-shortener) |
| condition | enum | yes | `control` or `treatment` |
| run_number | integer | yes | 1-indexed within condition for this experiment |
| model | string | yes | Model identifier (e.g., claude-sonnet-4-20250514) |
| prompt_sha256 | hex string | yes | SHA-256 hash of the prompt file |
| input_tokens | integer | yes | Total input tokens consumed |
| output_tokens | integer | yes | Total output tokens produced |
| total_tokens | integer | yes | input_tokens + output_tokens |
| rtmx_tokens | integer | yes | Tokens from MCP tool responses (0 for control) |
| planning_tokens | integer | yes | Tokens before first code edit |
| execution_tokens | integer | yes | Tokens after first code edit |
| turns | integer | yes | Number of model invocations |
| backtracks | integer | yes | File re-reads and reverted edits |
| tool_calls_rtmx | integer | yes | Number of RTMX MCP tool calls |
| tool_calls_other | integer | yes | Number of non-RTMX tool calls |
| outcome | enum | yes | `PASS`, `PARTIAL`, `FAIL`, or `ERROR` |
| tests_total | integer | yes | Total test count from test suite |
| tests_passed | integer | yes | Passed test count |
| tests_failed | integer | yes | Failed test count |
| wall_clock_seconds | float | yes | Elapsed wall-clock time in seconds |
| knowledge_entropy | float | no | Entropy score of project (if computed) |
| transcript_path | path | yes | Relative path to session transcript |

## Invariants

- The header row is always present, even in an empty ledger
- Rows are append-only (never overwritten or deleted)
- `total_tokens` = `input_tokens` + `output_tokens`
- `planning_tokens` + `execution_tokens` <= `total_tokens`
- `tests_passed` + `tests_failed` <= `tests_total`
- `condition` is always `control` or `treatment`
- `outcome` is always `PASS`, `PARTIAL`, `FAIL`, or `ERROR`
- `rtmx_tokens` = 0 and `tool_calls_rtmx` = 0 when condition = `control`

## Usage

```bash
# Validate the ledger
./lib/csv.sh validate results/summary.csv

# Initialize an empty ledger
./lib/csv.sh init results/summary.csv
```
