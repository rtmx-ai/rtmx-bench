#!/usr/bin/env bash
# score.sh -- Composite knowledge entropy score
# REQ-ENTROPY-005: Composite entropy score normalizes and weights all dimensions
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scan.sh"
source "$SCRIPT_DIR/staleness.sh"

# Compute composite entropy score
# Args: repo_path [--navigability N] [--duplication]
# Output: JSON with composite score and per-dimension breakdown
entropy_score() {
    local repo_path="${1:?Usage: entropy_score <repo_path>}"
    shift

    local nav_score=""
    local run_duplication=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --navigability) nav_score="$2"; shift 2 ;;
            --duplication)  run_duplication=1; shift ;;
            *)              shift ;;
        esac
    done

    # Collect dimension data
    local scatter_json staleness_json
    scatter_json=$(entropy_scan "$repo_path")
    staleness_json=$(entropy_staleness "$repo_path")

    local scatter_score scatter_depth
    scatter_score=$(echo "$scatter_json" | python3 -c "import sys,json; print(json.load(sys.stdin)['scatter_score'])")

    local staleness_pct
    staleness_pct=$(echo "$staleness_json" | python3 -c "import sys,json; print(json.load(sys.stdin)['staleness_score'])")

    # Duplication (optional, requires content analysis)
    local dup_score="null"
    if [[ $run_duplication -eq 1 ]]; then
        dup_score=$(echo "$scatter_json" | python3 "$SCRIPT_DIR/duplication.py" "$repo_path" | python3 -c "import sys,json; print(json.load(sys.stdin)['duplication_score'])")
    fi

    # Compute composite using normalize.py
    python3 "$SCRIPT_DIR/normalize.py" \
        --scatter "$scatter_score" \
        --staleness "$staleness_pct" \
        --navigability "${nav_score:-null}" \
        --duplication "$dup_score"
}

# Pretty-print entropy score
entropy_score_report() {
    local repo_path="${1:?Usage: entropy_score_report <repo_path>}"
    shift || true
    local json
    json=$(entropy_score "$repo_path" "$@")

    echo "=== Knowledge Entropy Score ==="
    echo ""
    echo "$json" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(f\"  Composite score: {data['entropy_score']:.1f} / 10.0\")
print()
print('  Dimensions:')
for dim in data['dimensions']:
    name = dim['name']
    raw = dim['raw']
    norm = dim['normalized']
    weight = dim['weight']
    included = 'included' if dim['included'] else 'excluded (unavailable)'
    print(f'    {name:15s}  raw={raw:8s}  norm={norm:.2f}  weight={weight:.2f}  {included}')
print()
score = data['entropy_score']
if score < 3:
    print('  Interpretation: LOW entropy -- knowledge is well-organized')
elif score < 6:
    print('  Interpretation: MODERATE entropy -- some scattered or stale documentation')
else:
    print('  Interpretation: HIGH entropy -- knowledge is scattered, stale, or duplicated')
"
}

# Subcommand dispatch
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    cmd="${1:-report}"
    shift || true
    case "$cmd" in
        scan)   entropy_score "$@" ;;
        report) entropy_score_report "$@" ;;
        help)
            echo "Usage: score.sh <command> <repo_path> [--duplication] [--navigability N]"
            echo "Commands:"
            echo "  scan <path>    Output JSON entropy score"
            echo "  report <path>  Pretty-print entropy report"
            ;;
        *)
            echo "Unknown command: $cmd" >&2
            exit 1
            ;;
    esac
fi
