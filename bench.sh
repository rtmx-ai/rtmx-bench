#!/usr/bin/env bash
# bench.sh -- Experiment runner for rtmx-bench
# REQ-HARNESS-001: Experiment runner executes controlled A/B sessions
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/csv.sh"

# Defaults
DEFAULT_MODEL="claude-sonnet-4-20250514"
DEFAULT_RUNS=5
RESULTS_DIR="$SCRIPT_DIR/results"
LEDGER="$RESULTS_DIR/summary.csv"

usage() {
    cat <<EOF
Usage: bench.sh <command> [options]

Commands:
  run <experiment>     Run an experiment
  validate <experiment> Validate experiment configuration
  init-ledger          Initialize the results ledger

Run options:
  --condition <control|treatment>  Condition to run (required)
  --runs <N>                       Number of runs (default: $DEFAULT_RUNS)
  --model <model>                  Claude model (default: $DEFAULT_MODEL)
  --dry-run                        Validate setup without invoking model

Examples:
  bench.sh run url-shortener --condition control --runs 5
  bench.sh run url-shortener --condition treatment --runs 5
  bench.sh validate url-shortener
  bench.sh init-ledger
EOF
}

# Load experiment configuration
# Args: experiment_name
# Sets: EXP_NAME, EXP_REPO, EXP_TEST_CMD, EXP_SETUP_CMD, EXP_FIXTURE_DIR
load_experiment() {
    local name="${1:?experiment name required}"
    local config="$SCRIPT_DIR/experiments/${name}.yaml"

    if [[ ! -f "$config" ]]; then
        echo "ERROR: Experiment config not found: $config" >&2
        return 1
    fi

    EXP_NAME="$name"
    EXP_REPO=$(python3 -c "import yaml; print(yaml.safe_load(open('$config'))['repo'])" 2>/dev/null || echo "")
    EXP_TEST_CMD=$(python3 -c "import yaml; print(yaml.safe_load(open('$config'))['test_command'])" 2>/dev/null || echo "")
    EXP_SETUP_CMD=$(python3 -c "import yaml; print(yaml.safe_load(open('$config')).get('setup_command', ''))" 2>/dev/null || echo "")
    EXP_FIXTURE_DIR="$SCRIPT_DIR/fixtures/$name"

    if [[ -z "$EXP_TEST_CMD" ]]; then
        echo "ERROR: Experiment '$name' has no test_command defined" >&2
        return 1
    fi
}

# Validate experiment configuration
validate_experiment() {
    local name="${1:?experiment name required}"
    local errors=0

    echo "Validating experiment: $name"

    # Config exists and loads
    if ! load_experiment "$name" 2>/dev/null; then
        echo "  [FAIL] Config file missing or invalid" >&2
        return 1
    fi
    echo "  [PASS] Config loads"

    # Prompt exists
    local prompt="$SCRIPT_DIR/prompts/${name}.md"
    if [[ ! -f "$prompt" ]]; then
        echo "  [FAIL] Prompt file missing: $prompt" >&2
        errors=$((errors + 1))
    else
        # Check prompt for RTMX references (experimental control violation)
        if grep -qi -E '\b(rtmx|rtm|mcp|requirements.traceability)\b' "$prompt" 2>/dev/null; then
            echo "  [FAIL] Prompt contains RTMX/RTM/MCP references (violates prompt identity)" >&2
            errors=$((errors + 1))
        else
            echo "  [PASS] Prompt exists, no RTMX references"
        fi
    fi

    # Fixture exists for treatment condition
    if [[ ! -d "$EXP_FIXTURE_DIR" ]]; then
        echo "  [WARN] No fixture directory: $EXP_FIXTURE_DIR (treatment condition unavailable)"
    elif [[ ! -f "$EXP_FIXTURE_DIR/rtm.csv" ]]; then
        echo "  [FAIL] Fixture missing rtm.csv: $EXP_FIXTURE_DIR/rtm.csv" >&2
        errors=$((errors + 1))
    else
        echo "  [PASS] Fixture RTM exists"
    fi

    if [[ $errors -eq 0 ]]; then
        echo "  Result: VALID"
        return 0
    else
        echo "  Result: INVALID ($errors errors)"
        return 1
    fi
}

# Set up a clean working directory for one run
# Args: experiment_name condition workdir
setup_workdir() {
    local name="$1" condition="$2" workdir="$3"

    # For greenfield experiments, just create an empty directory
    if [[ -z "$EXP_REPO" || "$EXP_REPO" == "none" ]]; then
        mkdir -p "$workdir"
    else
        # Clone the repo
        git clone --quiet "$EXP_REPO" "$workdir"
    fi

    # Run setup command if specified
    if [[ -n "$EXP_SETUP_CMD" ]]; then
        (cd "$workdir" && eval "$EXP_SETUP_CMD")
    fi

    # Seed RTMX for treatment condition
    if [[ "$condition" == "treatment" ]]; then
        if [[ ! -d "$EXP_FIXTURE_DIR" ]]; then
            echo "ERROR: Treatment condition requires fixture at $EXP_FIXTURE_DIR" >&2
            return 1
        fi
        mkdir -p "$workdir/.rtmx"
        cp "$EXP_FIXTURE_DIR/rtm.csv" "$workdir/.rtmx/database.csv"
        if [[ -d "$EXP_FIXTURE_DIR/requirements" ]]; then
            cp -r "$EXP_FIXTURE_DIR/requirements" "$workdir/.rtmx/requirements"
        fi
        # Create minimal config for RTMX
        cat > "$workdir/.rtmx/config.yaml" <<YAML
project:
  name: $name
rtm:
  database: .rtmx/database.csv
  requirements_dir: .rtmx/requirements
  schema: core
YAML
    fi
}

# Execute a single run
# Args: experiment condition run_number model workdir
execute_run() {
    local experiment="$1" condition="$2" run_number="$3" model="$4" workdir="$5"
    local prompt="$SCRIPT_DIR/prompts/${experiment}.md"
    local prompt_sha
    prompt_sha=$(shasum -a 256 "$prompt" | cut -d' ' -f1)

    local session_id
    session_id=$(python3 -c "import uuid; print(uuid.uuid4())")
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local result_dir="$RESULTS_DIR/raw/$experiment/$condition/$session_id"
    mkdir -p "$result_dir"

    echo "[$condition] Run $run_number -- session $session_id"

    local start_time
    start_time=$(date +%s)

    # Run Claude Code with the prompt (from the working directory)
    local prompt_text
    prompt_text=$(cat "$prompt")
    local exit_code=0
    (cd "$workdir" && claude --model "$model" \
        -p "$prompt_text" \
        --output-format stream-json --verbose \
        --max-budget-usd 5.00 \
        --dangerously-skip-permissions \
        > "$result_dir/transcript.jsonl" 2>"$result_dir/stderr.log") || exit_code=$?

    local end_time
    end_time=$(date +%s)
    local wall_clock=$((end_time - start_time))

    # Extract token counts from transcript (REQ-HARNESS-002)
    local input_tokens=0 output_tokens=0 total_tokens=0
    local rtmx_tokens=0 planning_tokens=0 execution_tokens=0
    local turns=0 backtracks=0 tool_calls_rtmx=0 tool_calls_other=0
    if [[ -f "$result_dir/transcript.jsonl" ]]; then
        local token_output
        token_output=$(python3 "$SCRIPT_DIR/lib/parse_transcript.py" "$result_dir/transcript.jsonl" 2>"$result_dir/token_detail.json" || echo "0 0 0 0 0 0 0 0 0 0")
        read -r input_tokens output_tokens total_tokens rtmx_tokens planning_tokens \
            execution_tokens turns backtracks tool_calls_rtmx tool_calls_other <<< "$token_output"
    fi

    # Run outcome verification
    local outcome="ERROR" tests_total=0 tests_passed=0 tests_failed=0
    if [[ $exit_code -ne 0 && ! -f "$result_dir/transcript.jsonl" ]]; then
        outcome="ERROR"
    else
        source "$SCRIPT_DIR/lib/verify.sh"
        verify_outcome "$workdir" "$EXP_TEST_CMD" "$result_dir/test_output.txt"
        outcome="$VERIFY_OUTCOME"
        tests_total="$VERIFY_TOTAL"
        tests_passed="$VERIFY_PASSED"
        tests_failed="$VERIFY_FAILED"
    fi

    local knowledge_entropy=""

    # Append to ledger
    ledger_append "$LEDGER" \
        "$session_id" "$timestamp" "$experiment" "$condition" "$run_number" \
        "$model" "$prompt_sha" \
        "$input_tokens" "$output_tokens" "$total_tokens" \
        "$rtmx_tokens" "$planning_tokens" "$execution_tokens" \
        "$turns" "$backtracks" "$tool_calls_rtmx" "$tool_calls_other" \
        "$outcome" "$tests_total" "$tests_passed" "$tests_failed" \
        "$wall_clock" "$knowledge_entropy" \
        "results/raw/$experiment/$condition/$session_id"

    # Preserve workdir for inspection
    cp -r "$workdir" "$result_dir/workdir"

    echo "  Outcome: $outcome | Tokens: $total_tokens | Time: ${wall_clock}s"
}

# Main run command
cmd_run() {
    local experiment="" condition="" runs=$DEFAULT_RUNS model=$DEFAULT_MODEL dry_run=0

    # Parse first positional arg as experiment name
    if [[ $# -gt 0 && ! "$1" =~ ^-- ]]; then
        experiment="$1"
        shift
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --condition)  condition="$2"; shift 2 ;;
            --runs)       runs="$2"; shift 2 ;;
            --model)      model="$2"; shift 2 ;;
            --dry-run)    dry_run=1; shift ;;
            *)            echo "Unknown option: $1" >&2; return 1 ;;
        esac
    done

    if [[ -z "$experiment" ]]; then
        echo "ERROR: Experiment name required" >&2
        usage
        return 1
    fi
    if [[ -z "$condition" ]]; then
        echo "ERROR: --condition required (control|treatment)" >&2
        return 1
    fi
    if [[ "$condition" != "control" && "$condition" != "treatment" ]]; then
        echo "ERROR: condition must be 'control' or 'treatment'" >&2
        return 1
    fi

    load_experiment "$experiment"

    if [[ $dry_run -eq 1 ]]; then
        echo "=== Dry Run ==="
        validate_experiment "$experiment"
        echo ""
        echo "Would run $runs sessions for condition '$condition' with model '$model'"
        return 0
    fi

    # Ensure ledger exists
    if [[ ! -f "$LEDGER" ]]; then
        ledger_init "$LEDGER"
    fi

    echo "=== rtmx-bench: $experiment ($condition, $runs runs) ==="
    echo "Model: $model"
    echo ""

    for i in $(seq 1 "$runs"); do
        local workdir
        workdir=$(mktemp -d "/tmp/rtmx-bench-${experiment}-${condition}-XXXXXX")

        setup_workdir "$experiment" "$condition" "$workdir"
        execute_run "$experiment" "$condition" "$i" "$model" "$workdir"

        # Clean up temp directory (workdir preserved in results/)
        rm -rf "$workdir"
    done

    echo ""
    echo "=== Complete: $runs runs recorded to $LEDGER ==="
}

# Dispatch
case "${1:-help}" in
    run)          shift; cmd_run "$@" ;;
    validate)     shift; validate_experiment "$@" ;;
    init-ledger)  ledger_init "$LEDGER" ;;
    help|--help)  usage ;;
    *)            echo "Unknown command: $1" >&2; usage; exit 1 ;;
esac
