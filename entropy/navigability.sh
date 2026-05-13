#!/usr/bin/env bash
# navigability.sh -- Agent probe sessions for navigability scoring
# REQ-ENTROPY-003: Navigability score measures file reads to answer questions
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BENCH_DIR="$(dirname "$SCRIPT_DIR")"
QUESTIONS_FILE="$SCRIPT_DIR/questions.txt"

DEFAULT_MODEL="claude-sonnet-4-20250514"
MAX_TOKENS=10000
TIMEOUT=60

# Run a single probe session
# Args: repo_path question model output_dir
# Returns: number of file reads
run_probe() {
    local repo_path="$1" question="$2" model="$3" output_dir="$4"

    mkdir -p "$output_dir"

    local exit_code=0
    timeout "$TIMEOUT" claude --model "$model" \
        --prompt "$question" \
        --output-format json \
        --max-turns 10 \
        --cwd "$repo_path" \
        > "$output_dir/transcript.json" 2>"$output_dir/stderr.log" || exit_code=$?

    if [[ ! -f "$output_dir/transcript.json" ]]; then
        echo "0"
        return
    fi

    # Count file read operations
    local read_count
    read_count=$(python3 -c "
import json
try:
    data = json.load(open('$output_dir/transcript.json'))
    messages = data if isinstance(data, list) else data.get('messages', [])
    reads = 0
    for msg in messages:
        if not isinstance(msg, dict):
            continue
        content = msg.get('content', [])
        if isinstance(content, str):
            continue
        for block in content:
            if isinstance(block, dict) and block.get('type') == 'tool_use':
                name = block.get('name', '')
                if name in ('Read', 'Glob', 'Grep'):
                    reads += 1
    print(reads)
except:
    print(0)
" 2>/dev/null || echo 0)
    echo "$read_count"
}

# Run all probe questions against a repo
# Args: repo_path [--model model] [--output-dir dir]
entropy_navigability() {
    local repo_path="${1:?Usage: entropy_navigability <repo_path>}"
    shift

    local model="$DEFAULT_MODEL"
    local output_dir=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --model)   model="$2"; shift 2 ;;
            --output)  output_dir="$2"; shift 2 ;;
            *)         echo "Unknown option: $1" >&2; return 1 ;;
        esac
    done

    if [[ -z "$output_dir" ]]; then
        output_dir=$(mktemp -d "/tmp/rtmx-bench-nav-XXXXXX")
    fi

    local questions=()
    while IFS= read -r line; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        questions+=("$line")
    done < "$QUESTIONS_FILE"

    local total_reads=0
    local question_count=0
    local results_json="["
    local first=1

    for question in "${questions[@]}"; do
        question_count=$((question_count + 1))
        local q_dir="$output_dir/q${question_count}"

        local reads
        reads=$(run_probe "$repo_path" "$question" "$model" "$q_dir")
        total_reads=$((total_reads + reads))

        # Extract tokens if transcript exists
        local tokens=0
        if [[ -f "$q_dir/transcript.json" ]]; then
            tokens=$(python3 -c "
import json
try:
    data = json.load(open('$q_dir/transcript.json'))
    if isinstance(data, dict):
        print(data.get('usage', {}).get('input_tokens', 0) + data.get('usage', {}).get('output_tokens', 0))
    elif isinstance(data, list):
        total = sum(m.get('usage', {}).get('input_tokens', 0) + m.get('usage', {}).get('output_tokens', 0) for m in data if isinstance(m, dict))
        print(total)
    else:
        print(0)
except:
    print(0)
" 2>/dev/null || echo 0)
        fi

        [[ $first -eq 0 ]] && results_json+=","
        first=0
        results_json+="{\"question\":\"$question\",\"file_reads\":$reads,\"tokens\":$tokens}"
    done
    results_json+="]"

    local mean_reads=0
    if [[ $question_count -gt 0 ]]; then
        mean_reads=$(python3 -c "print(round($total_reads / $question_count, 1))")
    fi

    cat <<EOF
{
  "navigability_score": $mean_reads,
  "total_reads": $total_reads,
  "question_count": $question_count,
  "questions": $results_json
}
EOF
}

# Subcommand dispatch
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    cmd="${1:-scan}"
    shift || true
    case "$cmd" in
        scan)   entropy_navigability "$@" ;;
        help)
            echo "Usage: navigability.sh scan <repo_path> [--model M] [--output DIR]"
            ;;
        *)
            echo "Unknown command: $cmd" >&2
            exit 1
            ;;
    esac
fi
