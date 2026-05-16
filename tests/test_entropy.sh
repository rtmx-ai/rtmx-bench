#!/usr/bin/env bash
# Tests for entropy scanner (REQ-ENTROPY-001, REQ-ENTROPY-002)
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

# --- Scatter Score Tests (REQ-ENTROPY-001) ---
echo "=== Scatter Score Tests ==="

source "$BENCH_DIR/entropy/scan.sh"

# Test: scan a repo with known intent files
# Use rtmx-bench itself as the test subject (it has README.md, CLAUDE.md, CONTRIBUTING.md, docs/)
tmpdir=$(mktemp -d)
mkdir -p "$tmpdir/test-repo/.git" "$tmpdir/test-repo/docs"
(cd "$tmpdir/test-repo" && git init --quiet)
echo "# Test Project" > "$tmpdir/test-repo/README.md"
echo "# TODO" > "$tmpdir/test-repo/TODO.md"
echo "# Architecture" > "$tmpdir/test-repo/docs/ARCHITECTURE.md"
echo "# Guide" > "$tmpdir/test-repo/docs/guide.md"
echo "// TODO: fix this" > "$tmpdir/test-repo/main.go"
(cd "$tmpdir/test-repo" && git add -A && git commit -m "init" --quiet)

json=$(entropy_scan "$tmpdir/test-repo")
scatter_score=$(echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin)['scatter_score'])")
scatter_depth=$(echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin)['scatter_depth'])")
inline_markers=$(echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin)['inline_markers'])")

assert_gt "finds intent files" 0 "$scatter_score"
assert_gt "finds multiple directories" 0 "$scatter_depth"
assert_gt "finds inline TODO markers" 0 "$inline_markers"

# Test: scan outputs valid JSON
python3 -c "import json; json.loads('''$json''')" 2>/dev/null
assert_eq "outputs valid JSON" "0" "$?"

# Test: empty repo has low scatter
empty_repo=$(mktemp -d)
mkdir -p "$empty_repo/.git"
(cd "$empty_repo" && git init --quiet && echo "x" > x.go && git add -A && git commit -m "init" --quiet)
empty_json=$(entropy_scan "$empty_repo")
empty_score=$(echo "$empty_json" | python3 -c "import sys,json; print(json.load(sys.stdin)['scatter_score'])")
assert_eq "empty repo has zero scatter" "0" "$empty_score"

rm -rf "$tmpdir" "$empty_repo"

# --- Dependency Directory Exclusion Tests (REQ-ENTROPY-007) ---
echo ""
echo "=== Dependency Directory Exclusion Tests ==="

dep_repo=$(mktemp -d)
(cd "$dep_repo" && git init --quiet)
echo "# Project" > "$dep_repo/README.md"
# Simulate node_modules with README files (the observed bug)
mkdir -p "$dep_repo/node_modules/express" "$dep_repo/node_modules/lodash"
echo "# Express" > "$dep_repo/node_modules/express/README.md"
echo "# Lodash" > "$dep_repo/node_modules/lodash/README.md"
# Simulate .venv with README
mkdir -p "$dep_repo/.venv/lib"
echo "# venv" > "$dep_repo/.venv/README.md"
# Simulate vendor with README
mkdir -p "$dep_repo/vendor/pkg"
echo "# Vendor" > "$dep_repo/vendor/pkg/README.md"
(cd "$dep_repo" && git add -A && git commit -m "init" --quiet)

dep_json=$(entropy_scan "$dep_repo")
dep_score=$(echo "$dep_json" | python3 -c "import sys,json; print(json.load(sys.stdin)['scatter_score'])")
# Should find only the root README.md, not the ones in node_modules/.venv/vendor
assert_eq "excludes dependency dir READMEs" "1" "$dep_score"

# Verify specific paths are NOT in the file list
dep_files=$(echo "$dep_json" | python3 -c "import sys,json; print(' '.join(f['path'] for f in json.load(sys.stdin)['files']))")
echo "$dep_files" | grep -q "node_modules" && {
    echo "  [FAIL] node_modules files should be excluded"
    FAIL=$((FAIL + 1))
} || {
    echo "  [PASS] node_modules excluded from results"
    PASS=$((PASS + 1))
}

rm -rf "$dep_repo"

# --- Patterns File Tests ---
echo ""
echo "=== Patterns File Tests ==="

assert_eq "patterns.txt exists" "0" "$(test -f "$BENCH_DIR/entropy/patterns.txt" && echo 0 || echo 1)"

pattern_count=$(grep -v '^#' "$BENCH_DIR/entropy/patterns.txt" | grep -v '^$' | wc -l | tr -d ' ')
assert_gt "patterns file has entries" 0 "$pattern_count"

# --- Summary ---
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
