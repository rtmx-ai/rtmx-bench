#!/usr/bin/env bash
# csv.sh -- Ledger row construction and validation for rtmx-bench
# REQ-DATA-001: CSV ledger defines 23-column schema for all experiment run data
set -euo pipefail

LEDGER_COLUMNS=(
    session_id
    timestamp
    experiment
    condition
    run_number
    model
    prompt_sha256
    input_tokens
    output_tokens
    total_tokens
    rtmx_tokens
    planning_tokens
    execution_tokens
    turns
    backtracks
    tool_calls_rtmx
    tool_calls_other
    outcome
    tests_total
    tests_passed
    tests_failed
    wall_clock_seconds
    knowledge_entropy
    transcript_path
)

LEDGER_HEADER=$(IFS=,; echo "${LEDGER_COLUMNS[*]}")
EXPECTED_COLUMN_COUNT=${#LEDGER_COLUMNS[@]}

# Initialize an empty ledger with the header row
ledger_init() {
    local path="${1:?Usage: ledger_init <path>}"
    if [[ -f "$path" ]]; then
        echo "ERROR: Ledger already exists: $path" >&2
        return 1
    fi
    mkdir -p "$(dirname "$path")"
    echo "$LEDGER_HEADER" > "$path"
    echo "Initialized ledger: $path ($EXPECTED_COLUMN_COUNT columns)" >&2
}

# Append a row to the ledger atomically
# Args: ledger_path field1 field2 ... field24
ledger_append() {
    local path="${1:?Usage: ledger_append <path> <field1> ... <fieldN>}"
    shift

    if [[ ! -f "$path" ]]; then
        echo "ERROR: Ledger does not exist: $path (run ledger_init first)" >&2
        return 1
    fi

    if [[ $# -ne $EXPECTED_COLUMN_COUNT ]]; then
        echo "ERROR: Expected $EXPECTED_COLUMN_COUNT fields, got $#" >&2
        return 1
    fi

    local row
    row=$(IFS=,; echo "$*")

    # Atomic append: write to temp file, then move
    local tmpfile
    tmpfile=$(mktemp "${path}.XXXXXX")
    cat "$path" > "$tmpfile"
    echo "$row" >> "$tmpfile"
    mv "$tmpfile" "$path"
}

# Validate ledger schema and data integrity
ledger_validate() {
    local path="${1:?Usage: ledger_validate <path>}"
    local errors=0

    if [[ ! -f "$path" ]]; then
        echo "ERROR: Ledger not found: $path" >&2
        return 1
    fi

    # Check header
    local header
    header=$(head -1 "$path")
    if [[ "$header" != "$LEDGER_HEADER" ]]; then
        echo "ERROR: Header mismatch" >&2
        echo "  Expected: $LEDGER_HEADER" >&2
        echo "  Got:      $header" >&2
        errors=$((errors + 1))
    fi

    # Check each data row (skip header)
    local line_num=0
    while IFS= read -r line; do
        line_num=$((line_num + 1))
        [[ $line_num -eq 1 ]] && continue  # skip header

        local col_count
        col_count=$(echo "$line" | awk -F, '{print NF}')
        if [[ "$col_count" -ne "$EXPECTED_COLUMN_COUNT" ]]; then
            echo "ERROR: Line $line_num: expected $EXPECTED_COLUMN_COUNT columns, got $col_count" >&2
            errors=$((errors + 1))
            continue
        fi

        # Validate condition field (column 4)
        local condition
        condition=$(echo "$line" | cut -d, -f4)
        if [[ "$condition" != "control" && "$condition" != "treatment" ]]; then
            echo "ERROR: Line $line_num: invalid condition '$condition' (must be control|treatment)" >&2
            errors=$((errors + 1))
        fi

        # Validate outcome field (column 18)
        local outcome
        outcome=$(echo "$line" | cut -d, -f18)
        if [[ "$outcome" != "PASS" && "$outcome" != "PARTIAL" && "$outcome" != "FAIL" && "$outcome" != "ERROR" && "$outcome" != "TIMEOUT" ]]; then
            echo "ERROR: Line $line_num: invalid outcome '$outcome' (must be PASS|PARTIAL|FAIL|ERROR|TIMEOUT)" >&2
            errors=$((errors + 1))
        fi

        # Validate total_tokens = input_tokens + output_tokens
        local input_tokens output_tokens total_tokens
        input_tokens=$(echo "$line" | cut -d, -f8)
        output_tokens=$(echo "$line" | cut -d, -f9)
        total_tokens=$(echo "$line" | cut -d, -f10)
        if [[ $((input_tokens + output_tokens)) -ne "$total_tokens" ]]; then
            echo "ERROR: Line $line_num: total_tokens ($total_tokens) != input ($input_tokens) + output ($output_tokens)" >&2
            errors=$((errors + 1))
        fi

        # Validate control condition has zero RTMX tokens
        if [[ "$condition" == "control" ]]; then
            local rtmx_tokens tool_calls_rtmx
            rtmx_tokens=$(echo "$line" | cut -d, -f11)
            tool_calls_rtmx=$(echo "$line" | cut -d, -f16)
            if [[ "$rtmx_tokens" -ne 0 ]]; then
                echo "ERROR: Line $line_num: control condition has non-zero rtmx_tokens ($rtmx_tokens)" >&2
                errors=$((errors + 1))
            fi
            if [[ "$tool_calls_rtmx" -ne 0 ]]; then
                echo "ERROR: Line $line_num: control condition has non-zero tool_calls_rtmx ($tool_calls_rtmx)" >&2
                errors=$((errors + 1))
            fi
        fi
    done < "$path"

    local data_rows=$((line_num > 0 ? line_num - 1 : 0))
    if [[ $errors -eq 0 ]]; then
        echo "VALID: $path ($data_rows data rows, $EXPECTED_COLUMN_COUNT columns)" >&2
        return 0
    else
        echo "INVALID: $path ($errors errors in $data_rows data rows)" >&2
        return 1
    fi
}

# Subcommand dispatch when run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    cmd="${1:-help}"
    shift || true
    case "$cmd" in
        init)     ledger_init "$@" ;;
        append)   ledger_append "$@" ;;
        validate) ledger_validate "$@" ;;
        help)
            echo "Usage: csv.sh <command> [args]"
            echo "Commands:"
            echo "  init <path>           Initialize empty ledger"
            echo "  append <path> <vals>  Append a row"
            echo "  validate <path>       Validate ledger schema"
            ;;
        *)
            echo "Unknown command: $cmd" >&2
            exit 1
            ;;
    esac
fi
