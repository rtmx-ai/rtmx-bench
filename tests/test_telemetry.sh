#!/usr/bin/env bash
# Tests for telemetry schema, NDJSON parsing, and ledger integrity
# REQ-HARNESS-002: Token accounting with RTMX attribution
# REQ-DATA-001: Ledger schema validation
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

assert_ge() {
    local label="$1" threshold="$2" actual="$3"
    if [[ "$actual" -ge "$threshold" ]]; then
        echo "  [PASS] $label ($actual >= $threshold)"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] $label: expected >= $threshold, got $actual"
        FAIL=$((FAIL + 1))
    fi
}

# --- NDJSON (stream-json) Parsing Tests ---
echo "=== NDJSON Transcript Parsing Tests ==="

tmpdir=$(mktemp -d)

# Test: parse stream-json format with result summary
cat > "$tmpdir/stream.jsonl" <<'EOF'
{"type":"system","message":{"role":"system","content":"You are an assistant"}}
{"type":"user","message":{"role":"user","content":[{"type":"text","text":"Build it"}]}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Let me start"},{"type":"tool_use","name":"Write","input":{"file_path":"/tmp/main.go","content":"package main"}}],"usage":{"input_tokens":500,"output_tokens":200}}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"mcp__rtmx__status","input":{}},{"type":"text","text":"Checking status"}],"usage":{"input_tokens":600,"output_tokens":150}}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"mcp__rtmx__next","input":{}},{"type":"text","text":"Getting next"}],"usage":{"input_tokens":700,"output_tokens":100}}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Edit","input":{"file_path":"/tmp/main.go","old_string":"a","new_string":"b"}},{"type":"text","text":"Editing"}],"usage":{"input_tokens":800,"output_tokens":300}}}
{"type":"result","usage":{"input_tokens":2000,"output_tokens":500,"cache_creation_input_tokens":100,"cache_read_input_tokens":50},"num_turns":4}
EOF

output=$(python3 "$BENCH_DIR/lib/parse_transcript.py" "$tmpdir/stream.jsonl" 2>/dev/null)
read -r input_tokens output_tokens total_tokens rtmx_tokens planning_tokens \
    execution_tokens turns backtracks tool_calls_rtmx tool_calls_other <<< "$output"

# Result summary should be used for input/output tokens (with cache)
assert_eq "NDJSON: input_tokens from result" "2150" "$input_tokens"
assert_eq "NDJSON: output_tokens from result" "500" "$output_tokens"
assert_eq "NDJSON: total_tokens" "2650" "$total_tokens"
assert_eq "NDJSON: turns from result" "4" "$turns"
assert_eq "NDJSON: rtmx tool calls" "2" "$tool_calls_rtmx"
assert_eq "NDJSON: other tool calls" "2" "$tool_calls_other"

# Test: planning tokens capture from first code edit (Write in msg 1)
# At first edit (Write): cumulative = 500+200 = 700
assert_eq "NDJSON: planning_tokens at first edit" "700" "$planning_tokens"

# Test: parse NDJSON without result summary (falls back to per-msg sums)
cat > "$tmpdir/no_result.jsonl" <<'EOF'
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Hello"}],"usage":{"input_tokens":100,"output_tokens":50}}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Bash","input":{"command":"echo hi"}}],"usage":{"input_tokens":200,"output_tokens":75}}}
EOF

output2=$(python3 "$BENCH_DIR/lib/parse_transcript.py" "$tmpdir/no_result.jsonl" 2>/dev/null)
read -r in2 out2 total2 _ _ _ turns2 _ _ _ <<< "$output2"
assert_eq "NDJSON fallback: input_tokens" "300" "$in2"
assert_eq "NDJSON fallback: output_tokens" "125" "$out2"
assert_eq "NDJSON fallback: turns" "2" "$turns2"

# Test: NDJSON with multiple result messages (only first used)
cat > "$tmpdir/multi_result.jsonl" <<'EOF'
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Working"}],"usage":{"input_tokens":100,"output_tokens":50}}}
{"type":"result","usage":{"input_tokens":1000,"output_tokens":400},"num_turns":5}
{"type":"result","usage":{"input_tokens":200,"output_tokens":80},"num_turns":2}
EOF

output3=$(python3 "$BENCH_DIR/lib/parse_transcript.py" "$tmpdir/multi_result.jsonl" 2>/dev/null)
read -r in3 out3 total3 _ _ _ turns3 _ _ _ <<< "$output3"
assert_eq "NDJSON: first result used" "1000" "$in3"
assert_eq "NDJSON: second result ignored" "400" "$out3"
assert_eq "NDJSON: turns from first result" "5" "$turns3"

# --- RTMX Tool Detection Tests ---
echo ""
echo "=== RTMX Tool Detection Tests ==="

# Test: all known RTMX tool prefixes are detected
cat > "$tmpdir/rtmx_tools.jsonl" <<'EOF'
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"mcp__rtmx__status","input":{}},{"type":"tool_use","name":"mcp__rtmx__next","input":{}},{"type":"tool_use","name":"mcp__rtmx__backlog","input":{}},{"type":"tool_use","name":"mcp__rtmx__verify","input":{}},{"type":"tool_use","name":"mcp__rtmx__health","input":{}},{"type":"tool_use","name":"mcp__rtmx__claim","input":{}},{"type":"tool_use","name":"mcp__rtmx__deps","input":{}},{"type":"tool_use","name":"mcp__rtmx__markers","input":{}},{"type":"tool_use","name":"mcp__rtmx__release","input":{}},{"type":"tool_use","name":"mcp__rtmx__release_assign","input":{}}],"usage":{"input_tokens":100,"output_tokens":50}}}
EOF

output4=$(python3 "$BENCH_DIR/lib/parse_transcript.py" "$tmpdir/rtmx_tools.jsonl" 2>/dev/null)
read -r _ _ _ _ _ _ _ _ rtmx4 other4 <<< "$output4"
assert_eq "all 10 RTMX MCP tools detected" "10" "$rtmx4"
assert_eq "no false positives" "0" "$other4"

# Test: rtmx_ prefix tools also detected (alternative naming)
cat > "$tmpdir/rtmx_alt.jsonl" <<'EOF'
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"rtmx_status","input":{}},{"type":"tool_use","name":"rtmx_verify","input":{}}],"usage":{"input_tokens":100,"output_tokens":50}}}
EOF

output5=$(python3 "$BENCH_DIR/lib/parse_transcript.py" "$tmpdir/rtmx_alt.jsonl" 2>/dev/null)
read -r _ _ _ _ _ _ _ _ rtmx5 _ <<< "$output5"
assert_eq "rtmx_ prefix detected" "2" "$rtmx5"

# Test: non-RTMX tools are counted as other
cat > "$tmpdir/other_tools.jsonl" <<'EOF'
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Read","input":{}},{"type":"tool_use","name":"Write","input":{}},{"type":"tool_use","name":"Bash","input":{}},{"type":"tool_use","name":"Edit","input":{}},{"type":"tool_use","name":"Grep","input":{}}],"usage":{"input_tokens":100,"output_tokens":50}}}
EOF

output6=$(python3 "$BENCH_DIR/lib/parse_transcript.py" "$tmpdir/other_tools.jsonl" 2>/dev/null)
read -r _ _ _ _ _ _ _ _ rtmx6 other6 <<< "$output6"
assert_eq "no RTMX tools in control-like transcript" "0" "$rtmx6"
assert_eq "5 other tools counted" "5" "$other6"

# --- Backtrack Detection Tests ---
echo ""
echo "=== Backtrack Detection Tests ==="

cat > "$tmpdir/backtracks.jsonl" <<'EOF'
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Read","input":{"file_path":"/tmp/a.go"}}],"usage":{"input_tokens":100,"output_tokens":50}}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Read","input":{"file_path":"/tmp/b.go"}}],"usage":{"input_tokens":100,"output_tokens":50}}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Read","input":{"file_path":"/tmp/a.go"}}],"usage":{"input_tokens":100,"output_tokens":50}}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Read","input":{"file_path":"/tmp/a.go"}}],"usage":{"input_tokens":100,"output_tokens":50}}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Read","input":{"file_path":"/tmp/c.go"}}],"usage":{"input_tokens":100,"output_tokens":50}}}
EOF

output7=$(python3 "$BENCH_DIR/lib/parse_transcript.py" "$tmpdir/backtracks.jsonl" 2>/dev/null)
read -r _ _ _ _ _ _ _ backtracks7 _ _ <<< "$output7"
# a.go read 3 times: 2 backtracks; b.go and c.go read once each: 0 backtracks
assert_eq "backtrack count for re-reads" "2" "$backtracks7"

# --- Ledger Schema Validation Tests ---
echo ""
echo "=== Ledger Schema Validation Tests ==="

source "$BENCH_DIR/lib/csv.sh"

# Test: valid treatment row passes validation
valid_ledger="$tmpdir/valid.csv"
ledger_init "$valid_ledger" 2>/dev/null
ledger_append "$valid_ledger" \
    "sess-1" "2026-05-13T00:00:00Z" "url-shortener" "treatment" "1" \
    "claude-sonnet-4-20250514" "abc123" \
    "1000" "500" "1500" "200" "400" "1100" \
    "10" "1" "3" "15" \
    "PASS" "25" "25" "0" \
    "300" "" "results/raw/test"
valid_exit=0
ledger_validate "$valid_ledger" 2>/dev/null || valid_exit=$?
assert_eq "valid treatment row passes" "0" "$valid_exit"

# Test: total_tokens mismatch fails validation
bad_total="$tmpdir/bad_total.csv"
ledger_init "$bad_total" 2>/dev/null
ledger_append "$bad_total" \
    "sess-2" "2026-05-13T00:00:00Z" "url-shortener" "control" "1" \
    "claude-sonnet-4-20250514" "abc123" \
    "1000" "500" "9999" "0" "400" "1100" \
    "10" "1" "0" "15" \
    "PASS" "10" "10" "0" \
    "120" "" "results/raw/test"
bad_total_exit=0
ledger_validate "$bad_total" 2>/dev/null || bad_total_exit=$?
assert_eq "total_tokens mismatch fails" "1" "$bad_total_exit"

# Test: invalid outcome value fails
bad_outcome="$tmpdir/bad_outcome.csv"
ledger_init "$bad_outcome" 2>/dev/null
ledger_append "$bad_outcome" \
    "sess-3" "2026-05-13T00:00:00Z" "url-shortener" "treatment" "1" \
    "claude-sonnet-4-20250514" "abc123" \
    "1000" "500" "1500" "0" "400" "1100" \
    "10" "1" "0" "15" \
    "INVALID_OUTCOME" "10" "10" "0" \
    "120" "" "results/raw/test"
bad_outcome_exit=0
ledger_validate "$bad_outcome" 2>/dev/null || bad_outcome_exit=$?
assert_eq "invalid outcome fails" "1" "$bad_outcome_exit"

# Test: column count mismatch fails
bad_cols="$tmpdir/bad_cols.csv"
echo "$LEDGER_HEADER" > "$bad_cols"
echo "too,few,columns" >> "$bad_cols"
bad_cols_exit=0
ledger_validate "$bad_cols" 2>/dev/null || bad_cols_exit=$?
assert_eq "column count mismatch fails" "1" "$bad_cols_exit"

# --- Live Ledger Validation Tests ---
echo ""
echo "=== Live Ledger Validation ==="

live_ledger="$BENCH_DIR/results/summary.csv"
if [[ -f "$live_ledger" ]]; then
    live_exit=0
    ledger_validate "$live_ledger" 2>/dev/null || live_exit=$?
    assert_eq "live ledger passes schema validation" "0" "$live_exit"

    # Test: run numbers are sequential within each condition
    for condition in control treatment; do
        run_nums=$(grep ",$condition," "$live_ledger" | cut -d, -f5 | sort -n)
        expected_seq=$(seq 1 $(echo "$run_nums" | wc -l | tr -d ' '))
        if [[ "$run_nums" == "$expected_seq" ]]; then
            echo "  [PASS] $condition run numbers are sequential (1..N)"
            PASS=$((PASS + 1))
        else
            echo "  [FAIL] $condition run numbers not sequential: got [$run_nums], expected [$expected_seq]"
            FAIL=$((FAIL + 1))
        fi
    done

    # Test: all runs use the same model
    models=$(tail -n +2 "$live_ledger" | cut -d, -f6 | sort -u)
    model_count=$(echo "$models" | wc -l | tr -d ' ')
    assert_eq "all runs use same model" "1" "$model_count"

    # Test: all runs use the same prompt (same sha256)
    prompts=$(tail -n +2 "$live_ledger" | cut -d, -f7 | sort -u)
    prompt_count=$(echo "$prompts" | wc -l | tr -d ' ')
    assert_eq "all runs use same prompt sha256" "1" "$prompt_count"

    # Test: all runs have non-empty transcript paths
    empty_paths=$(tail -n +2 "$live_ledger" | cut -d, -f24 | grep -c '^$' || true)
    assert_eq "all runs have transcript paths" "0" "$empty_paths"

    # Test: control runs have zero rtmx_tokens and tool_calls_rtmx
    control_rtmx=$(grep ",control," "$live_ledger" | cut -d, -f11 | sort -u)
    assert_eq "control rtmx_tokens all zero" "0" "$control_rtmx"
    control_rtmx_calls=$(grep ",control," "$live_ledger" | cut -d, -f16 | sort -u)
    assert_eq "control tool_calls_rtmx all zero" "0" "$control_rtmx_calls"
else
    echo "  [SKIP] No live ledger found at $live_ledger"
fi

# --- Planning/Execution Token Split Tests ---
echo ""
echo "=== Planning/Execution Split Tests ==="

# Test: no edits means all tokens are planning
cat > "$tmpdir/no_edits.jsonl" <<'EOF'
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Read","input":{"file_path":"/tmp/a.go"}}],"usage":{"input_tokens":500,"output_tokens":200}}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Bash","input":{"command":"ls"}}],"usage":{"input_tokens":300,"output_tokens":100}}}
EOF

output8=$(python3 "$BENCH_DIR/lib/parse_transcript.py" "$tmpdir/no_edits.jsonl" 2>/dev/null)
read -r _ _ total8 _ planning8 execution8 _ _ _ _ <<< "$output8"
assert_eq "no edits: all tokens are planning" "$total8" "$planning8"
assert_eq "no edits: execution is zero" "0" "$execution8"

# Test: first edit splits correctly
cat > "$tmpdir/with_edit.jsonl" <<'EOF'
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Read","input":{"file_path":"/tmp/a.go"}}],"usage":{"input_tokens":400,"output_tokens":100}}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Edit","input":{"file_path":"/tmp/a.go","old_string":"a","new_string":"b"}}],"usage":{"input_tokens":300,"output_tokens":200}}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Bash","input":{"command":"go test"}}],"usage":{"input_tokens":500,"output_tokens":150}}}
EOF

output9=$(python3 "$BENCH_DIR/lib/parse_transcript.py" "$tmpdir/with_edit.jsonl" 2>/dev/null)
read -r _ _ total9 _ planning9 execution9 _ _ _ _ <<< "$output9"
# Planning = cumulative at first Edit = (400+100) + (300+200) = 1000
assert_eq "edit split: planning tokens" "1000" "$planning9"
# Execution = total - planning = 1650 - 1000 = 650
assert_eq "edit split: execution tokens" "650" "$execution9"

rm -rf "$tmpdir"

# --- Summary ---
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
