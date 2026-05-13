#!/usr/bin/env bash
# reverify.sh -- Re-run test verification on preserved workdirs
# Usage: reverify.sh <experiment> [--update-ledger]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/csv.sh"

RESULTS_DIR="$SCRIPT_DIR/results"
LEDGER="$RESULTS_DIR/summary.csv"

experiment="${1:?experiment name required}"
update_ledger=0
if [[ "${2:-}" == "--update-ledger" ]]; then
    update_ledger=1
fi

config="$SCRIPT_DIR/experiments/${experiment}.yaml"
if [[ ! -f "$config" ]]; then
    echo "ERROR: Experiment config not found: $config" >&2
    exit 1
fi

test_cmd=$(python3 -c "import yaml; print(yaml.safe_load(open('$config'))['test_command'])" 2>/dev/null)

echo "=== Re-verifying: $experiment ==="
echo "Test command from current config"
echo ""

source "$SCRIPT_DIR/lib/verify.sh"

for condition_dir in "$RESULTS_DIR/raw/$experiment"/*/; do
    condition=$(basename "$condition_dir")
    for session_dir in "$condition_dir"*/; do
        session_id=$(basename "$session_dir")
        workdir="$session_dir/workdir"

        if [[ ! -d "$workdir" ]]; then
            echo "  [$condition/$session_id] SKIP -- no preserved workdir"
            continue
        fi

        verify_outcome "$workdir" "$test_cmd" "$session_dir/test_output_reverify.txt"

        echo "  [$condition/$session_id] $VERIFY_OUTCOME -- $VERIFY_PASSED/$VERIFY_TOTAL passed"
    done
done

echo ""
echo "=== Re-verification complete ==="
