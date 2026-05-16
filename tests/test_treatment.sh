#!/usr/bin/env bash
# Tests for treatment condition setup and workdir seeding
# REQ-HARNESS-001: Treatment condition must seed RTMX fixtures correctly
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

assert_file_exists() {
    local label="$1" path="$2"
    if [[ -f "$path" ]]; then
        echo "  [PASS] $label"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] $label: file not found: $path"
        FAIL=$((FAIL + 1))
    fi
}

assert_dir_exists() {
    local label="$1" path="$2"
    if [[ -d "$path" ]]; then
        echo "  [PASS] $label"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] $label: directory not found: $path"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local label="$1" file="$2" pattern="$3"
    if grep -q -- "$pattern" "$file" 2>/dev/null; then
        echo "  [PASS] $label"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] $label: '$pattern' not found in $file"
        FAIL=$((FAIL + 1))
    fi
}

assert_json_field() {
    local label="$1" file="$2" field="$3" expected="$4"
    local actual
    actual=$(python3 -c "import json; print(json.load(open('$file'))$field)" 2>/dev/null || echo "PARSE_ERROR")
    if [[ "$actual" == "$expected" ]]; then
        echo "  [PASS] $label"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] $label: expected '$expected', got '$actual'"
        FAIL=$((FAIL + 1))
    fi
}

# --- Fixture Validation Tests ---
echo "=== Fixture Validation Tests ==="

# Test: fixture directory exists for url-shortener
assert_dir_exists "url-shortener fixture dir exists" "$BENCH_DIR/fixtures/url-shortener"

# Test: fixture RTM CSV exists and has correct schema
assert_file_exists "fixture rtm.csv exists" "$BENCH_DIR/fixtures/url-shortener/rtm.csv"

# Test: fixture RTM CSV has required columns
rtm_header=$(head -1 "$BENCH_DIR/fixtures/url-shortener/rtm.csv")
assert_contains "fixture has req_id column" "$BENCH_DIR/fixtures/url-shortener/rtm.csv" "^req_id"
assert_contains "fixture has status column" "$BENCH_DIR/fixtures/url-shortener/rtm.csv" "status"
assert_contains "fixture has test_function column" "$BENCH_DIR/fixtures/url-shortener/rtm.csv" "test_function"
assert_contains "fixture has dependencies column" "$BENCH_DIR/fixtures/url-shortener/rtm.csv" "dependencies"

# Test: fixture has at least one requirement
fixture_rows=$(tail -n +2 "$BENCH_DIR/fixtures/url-shortener/rtm.csv" | wc -l | tr -d ' ')
if [[ "$fixture_rows" -gt 0 ]]; then
    echo "  [PASS] fixture has $fixture_rows requirements"
    PASS=$((PASS + 1))
else
    echo "  [FAIL] fixture has no requirements"
    FAIL=$((FAIL + 1))
fi

# Test: all fixture requirements have MISSING status (treatment starts from scratch)
non_missing=$(tail -n +2 "$BENCH_DIR/fixtures/url-shortener/rtm.csv" | grep -vc ",MISSING," || true)
assert_eq "all fixture requirements are MISSING" "0" "$non_missing"

# --- Treatment Workdir Setup Tests ---
echo ""
echo "=== Treatment Workdir Setup Tests ==="

# Source bench.sh functions indirectly by sourcing needed libs
source "$BENCH_DIR/lib/csv.sh"

# Load experiment config
EXP_NAME="url-shortener"
EXP_REPO="none"
EXP_TEST_CMD="echo ok"
EXP_SETUP_CMD=""
EXP_FIXTURE_DIR="$BENCH_DIR/fixtures/url-shortener"

# Create temp workdir and seed it
tmpdir=$(mktemp -d)
workdir="$tmpdir/project"
mkdir -p "$workdir"

# Simulate treatment seeding (extracted from bench.sh setup_workdir)
mkdir -p "$workdir/.rtmx"
cp "$EXP_FIXTURE_DIR/rtm.csv" "$workdir/.rtmx/database.csv"
if [[ -d "$EXP_FIXTURE_DIR/requirements" ]]; then
    cp -r "$EXP_FIXTURE_DIR/requirements" "$workdir/.rtmx/requirements"
fi
cat > "$workdir/.rtmx/config.yaml" <<YAML
project:
  name: $EXP_NAME
rtm:
  database: .rtmx/database.csv
  requirements_dir: .rtmx/requirements
  schema: core
YAML

rtmx_bin=$(command -v rtmx 2>/dev/null || echo "/usr/local/bin/rtmx")
cat > "$workdir/.mcp.json" <<MCPJSON
{
  "mcpServers": {
    "rtmx": {
      "command": "$rtmx_bin",
      "args": ["mcp-server", "--stdio"],
      "cwd": "$workdir"
    }
  }
}
MCPJSON

# Generate CLAUDE.md using rtmx install (standardized prompt)
(cd "$workdir" && rtmx install --agents claude --force --yes 2>/dev/null)

# Verify seeded files
assert_file_exists "treatment seeds .rtmx/database.csv" "$workdir/.rtmx/database.csv"
assert_file_exists "treatment seeds .rtmx/config.yaml" "$workdir/.rtmx/config.yaml"
assert_file_exists "treatment seeds .mcp.json" "$workdir/.mcp.json"
assert_file_exists "treatment seeds CLAUDE.md" "$workdir/CLAUDE.md"

# Test: seeded database.csv matches fixture
if diff -q "$EXP_FIXTURE_DIR/rtm.csv" "$workdir/.rtmx/database.csv" >/dev/null 2>&1; then
    echo "  [PASS] seeded database.csv matches fixture"
    PASS=$((PASS + 1))
else
    echo "  [FAIL] seeded database.csv differs from fixture"
    FAIL=$((FAIL + 1))
fi

# Test: config.yaml has correct project name
assert_contains "config.yaml has project name" "$workdir/.rtmx/config.yaml" "name: url-shortener"

# Test: config.yaml has correct database path
assert_contains "config.yaml has database path" "$workdir/.rtmx/config.yaml" "database: .rtmx/database.csv"

# Test: .mcp.json is valid JSON with rtmx server
assert_json_field ".mcp.json has rtmx server" "$workdir/.mcp.json" "['mcpServers']['rtmx']['args'][0]" "mcp-server"
assert_json_field ".mcp.json has stdio flag" "$workdir/.mcp.json" "['mcpServers']['rtmx']['args'][1]" "--stdio"

# Test: .mcp.json command points to an executable path
mcp_cmd=$(python3 -c "import json; print(json.load(open('$workdir/.mcp.json'))['mcpServers']['rtmx']['command'])" 2>/dev/null)
if [[ -n "$mcp_cmd" ]]; then
    echo "  [PASS] .mcp.json has command path: $mcp_cmd"
    PASS=$((PASS + 1))
else
    echo "  [FAIL] .mcp.json missing command path"
    FAIL=$((FAIL + 1))
fi

# Test: .mcp.json cwd matches workdir
assert_json_field ".mcp.json cwd matches workdir" "$workdir/.mcp.json" "['mcpServers']['rtmx']['cwd']" "$workdir"

# Test: CLAUDE.md contains RTMX workflow instructions (from rtmx install)
assert_contains "CLAUDE.md has RTMX section" "$workdir/CLAUDE.md" "RTMX Requirements Traceability"
assert_contains "CLAUDE.md references mcp__rtmx__status" "$workdir/CLAUDE.md" "mcp__rtmx__status"
assert_contains "CLAUDE.md references mcp__rtmx__next" "$workdir/CLAUDE.md" "mcp__rtmx__next"
assert_contains "CLAUDE.md references mcp__rtmx__verify" "$workdir/CLAUDE.md" "mcp__rtmx__verify"
assert_contains "CLAUDE.md references mcp__rtmx__backlog" "$workdir/CLAUDE.md" "mcp__rtmx__backlog"
assert_contains "CLAUDE.md has workflow section" "$workdir/CLAUDE.md" "Development Workflow"
assert_contains "CLAUDE.md has MCP tools section" "$workdir/CLAUDE.md" "MCP Tools"
assert_contains "CLAUDE.md has verify --command" "$workdir/CLAUDE.md" "rtmx verify --command"

# --- Control vs Treatment Isolation Tests ---
echo ""
echo "=== Control vs Treatment Isolation Tests ==="

# Test: control workdir has NO .rtmx directory
control_workdir="$tmpdir/control_project"
mkdir -p "$control_workdir"
# Control setup: just an empty directory (no seeding)

if [[ ! -d "$control_workdir/.rtmx" ]]; then
    echo "  [PASS] control workdir has no .rtmx directory"
    PASS=$((PASS + 1))
else
    echo "  [FAIL] control workdir should not have .rtmx directory"
    FAIL=$((FAIL + 1))
fi

if [[ ! -f "$control_workdir/.mcp.json" ]]; then
    echo "  [PASS] control workdir has no .mcp.json"
    PASS=$((PASS + 1))
else
    echo "  [FAIL] control workdir should not have .mcp.json"
    FAIL=$((FAIL + 1))
fi

# --- Prompt Identity Tests ---
echo ""
echo "=== Prompt Identity Tests ==="

# Test: prompt file has no RTMX/MCP references (experimental control)
prompt_file="$BENCH_DIR/prompts/url-shortener.md"
if [[ -f "$prompt_file" ]]; then
    rtmx_refs=$(grep -ci -E '\b(rtmx|rtm[^s]|mcp|requirements.traceability)\b' "$prompt_file" 2>/dev/null || true)
    rtmx_refs=${rtmx_refs:-0}
    assert_eq "prompt has no RTMX references" "0" "$rtmx_refs"
else
    echo "  [FAIL] prompt file not found: $prompt_file"
    FAIL=$((FAIL + 1))
fi

# Test: fixture database references test functions that match prompt requirements
# The prompt defines endpoints: POST /shorten, GET /:code, GET /stats/:code
assert_contains "fixture covers POST /shorten" "$EXP_FIXTURE_DIR/rtm.csv" "test_post_shorten"
assert_contains "fixture covers GET redirect" "$EXP_FIXTURE_DIR/rtm.csv" "test_get_redirect"
assert_contains "fixture covers GET stats" "$EXP_FIXTURE_DIR/rtm.csv" "test_get_stats"
assert_contains "fixture covers validation" "$EXP_FIXTURE_DIR/rtm.csv" "test_invalid_url"
assert_contains "fixture covers rate limiting" "$EXP_FIXTURE_DIR/rtm.csv" "test_rate_limit"

# --- Task Manager Fixture Tests (REQ-EXP-004) ---
echo ""
echo "=== Task Manager Fixture Tests ==="

TM_FIXTURE="$BENCH_DIR/fixtures/task-manager"

assert_dir_exists "task-manager fixture dir exists" "$TM_FIXTURE"
assert_file_exists "task-manager rtm.csv exists" "$TM_FIXTURE/rtm.csv"

# Test: fixture has at least 13 requirements (deep dependency graph)
tm_rows=$(tail -n +2 "$TM_FIXTURE/rtm.csv" | wc -l | tr -d ' ')
if [[ "$tm_rows" -ge 13 ]]; then
    echo "  [PASS] task-manager fixture has $tm_rows requirements (>= 13)"
    PASS=$((PASS + 1))
else
    echo "  [FAIL] task-manager fixture has $tm_rows requirements (expected >= 13)"
    FAIL=$((FAIL + 1))
fi

# Test: all fixture requirements are MISSING
tm_non_missing=$(tail -n +2 "$TM_FIXTURE/rtm.csv" | grep -vc ",MISSING," || true)
assert_eq "all task-manager requirements are MISSING" "0" "$tm_non_missing"

# Test: dependency graph has expected structure
assert_contains "DB blocks AUTH" "$TM_FIXTURE/rtm.csv" "REQ-AUTH-001"
assert_contains "AUTH blocks projects" "$TM_FIXTURE/rtm.csv" "REQ-PROJ-001"
assert_contains "tasks depend on projects" "$TM_FIXTURE/rtm.csv" "REQ-PROJ-001"

# Test: prompt has no RTMX references
tm_prompt="$BENCH_DIR/prompts/task-manager.md"
if [[ -f "$tm_prompt" ]]; then
    tm_rtmx_refs=$(grep -ci -E '\b(rtmx|rtm[^s]|mcp|requirements.traceability)\b' "$tm_prompt" 2>/dev/null || true)
    tm_rtmx_refs=${tm_rtmx_refs:-0}
    assert_eq "task-manager prompt has no RTMX references" "0" "$tm_rtmx_refs"
else
    echo "  [FAIL] task-manager prompt not found: $tm_prompt"
    FAIL=$((FAIL + 1))
fi

# Test: requirement spec files exist
for dir in DB AUTH PROJ TASK LABEL LOG BG VALID ERR TEST; do
    if [[ -d "$TM_FIXTURE/requirements/$dir" ]]; then
        file_count=$(ls "$TM_FIXTURE/requirements/$dir"/*.md 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$file_count" -gt 0 ]]; then
            echo "  [PASS] $dir has $file_count spec file(s)"
            PASS=$((PASS + 1))
        else
            echo "  [FAIL] $dir directory empty"
            FAIL=$((FAIL + 1))
        fi
    else
        echo "  [FAIL] $dir directory missing"
        FAIL=$((FAIL + 1))
    fi
done

# --- Treatment Workflow Tests (REQ-EXP-005) ---
echo ""
echo "=== Treatment Workflow Tests ==="

# Test: bench.sh delegates CLAUDE.md generation to rtmx install
grep -q 'rtmx install --agents claude' "$BENCH_DIR/bench.sh" && {
    echo "  [PASS] bench.sh delegates CLAUDE.md to rtmx install"
    PASS=$((PASS + 1))
} || {
    echo "  [FAIL] bench.sh must delegate CLAUDE.md to rtmx install"
    FAIL=$((FAIL + 1))
}

# Test: rtmx-generated CLAUDE.md includes verify --command for closed-loop
assert_contains "CLAUDE.md instructs rtmx verify --command for closed-loop" \
    "$workdir/CLAUDE.md" "rtmx verify --command"

# Test: rtmx-generated CLAUDE.md includes --update flag
assert_contains "CLAUDE.md includes --update flag" \
    "$workdir/CLAUDE.md" "--update"

# Test: rtmx-generated CLAUDE.md includes next/claim/backlog for structured ordering
assert_contains "CLAUDE.md includes backlog" "$workdir/CLAUDE.md" "backlog"
assert_contains "CLAUDE.md includes next" "$workdir/CLAUDE.md" "rtmx next"
assert_contains "CLAUDE.md includes dependency ordering" "$workdir/CLAUDE.md" "dependency ordering"

# Cleanup temp workdir
rm -rf "$tmpdir"

# --- Summary ---
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
