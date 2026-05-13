#!/usr/bin/env bash
# Tests for staleness scoring (REQ-ENTROPY-002)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BENCH_DIR="$(dirname "$SCRIPT_DIR")"
PASS=0
FAIL=0

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "  [PASS] $label"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] $label: expected '$expected', got '$actual'"
        FAIL=$((FAIL + 1))
    fi
}

assert_gt() {
    local label="$1" threshold="$2" actual="$3"
    if [[ "$actual" -gt "$threshold" ]]; then
        echo "  [PASS] $label ($actual > $threshold)"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] $label: expected > $threshold, got $actual"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== Staleness Score Tests ==="

source "$BENCH_DIR/entropy/staleness.sh"

# Test: fresh repo has zero staleness
tmpdir=$(mktemp -d)
(cd "$tmpdir" && git init --quiet && \
    echo "# README" > README.md && \
    echo "# TODO" > TODO.md && \
    git add -A && git commit -m "init" --quiet)

json=$(entropy_staleness "$tmpdir")
staleness_score=$(echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin)['staleness_score'])")
stale_count=$(echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin)['stale_count'])")
total_files=$(echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin)['total_intent_files'])")

assert_eq "fresh repo staleness is 0" "0.0" "$staleness_score"
assert_eq "fresh repo has 0 stale files" "0" "$stale_count"
assert_gt "fresh repo finds intent files" 0 "$total_files"

# Test: outputs valid JSON
python3 -c "import json; json.loads('''$json''')" 2>/dev/null
assert_eq "outputs valid JSON" "0" "$?"

# Test: all files classified as CURRENT in fresh repo
current_count=$(echo "$json" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(sum(1 for f in data['files'] if f['classification'] == 'CURRENT'))
")
assert_eq "all files CURRENT in fresh repo" "$total_files" "$current_count"

# Test: non-git directory is rejected
non_git=$(mktemp -d)
error_exit=0
entropy_staleness "$non_git" 2>/dev/null || error_exit=$?
assert_eq "non-git dir rejected" "1" "$error_exit"

# Test: empty repo (no commits) returns zero
empty_repo=$(mktemp -d)
(cd "$empty_repo" && git init --quiet)
empty_json=$(entropy_staleness "$empty_repo")
empty_total=$(echo "$empty_json" | python3 -c "import sys,json; print(json.load(sys.stdin)['total_intent_files'])")
assert_eq "empty repo has 0 intent files" "0" "$empty_total"

rm -rf "$tmpdir" "$non_git" "$empty_repo"

# --- Summary ---
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
