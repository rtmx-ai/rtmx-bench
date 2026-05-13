#!/usr/bin/env bash
# Tests for token accounting (REQ-HARNESS-002)
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

echo "=== Token Accounting Tests ==="

# Test: parse simple transcript with usage data
tmpdir=$(mktemp -d)
cat > "$tmpdir/transcript.json" <<'EOF'
[
  {
    "role": "user",
    "content": "Build a URL shortener"
  },
  {
    "role": "assistant",
    "content": [
      {"type": "tool_use", "name": "Read", "input": {"file_path": "/tmp/foo.go"}},
      {"type": "text", "text": "Let me read the code."}
    ],
    "usage": {"input_tokens": 500, "output_tokens": 200}
  },
  {
    "role": "assistant",
    "content": [
      {"type": "tool_use", "name": "mcp__rtmx__status", "input": {}},
      {"type": "text", "text": "Checking requirements."}
    ],
    "usage": {"input_tokens": 600, "output_tokens": 150}
  },
  {
    "role": "assistant",
    "content": [
      {"type": "tool_use", "name": "mcp__rtmx__next", "input": {}},
      {"type": "text", "text": "Getting next task."}
    ],
    "usage": {"input_tokens": 700, "output_tokens": 100}
  },
  {
    "role": "assistant",
    "content": [
      {"type": "tool_use", "name": "Edit", "input": {"file_path": "/tmp/foo.go", "old_string": "a", "new_string": "b"}},
      {"type": "text", "text": "Editing code."}
    ],
    "usage": {"input_tokens": 800, "output_tokens": 300}
  },
  {
    "role": "assistant",
    "content": [
      {"type": "tool_use", "name": "Read", "input": {"file_path": "/tmp/foo.go"}},
      {"type": "text", "text": "Re-reading after edit."}
    ],
    "usage": {"input_tokens": 500, "output_tokens": 100}
  }
]
EOF

output=$(python3 "$BENCH_DIR/lib/parse_transcript.py" "$tmpdir/transcript.json" 2>/dev/null)
read -r input_tokens output_tokens total_tokens rtmx_tokens planning_tokens \
    execution_tokens turns backtracks tool_calls_rtmx tool_calls_other <<< "$output"

assert_eq "input_tokens" "3100" "$input_tokens"
assert_eq "output_tokens" "850" "$output_tokens"
assert_eq "total_tokens" "3950" "$total_tokens"
assert_eq "turns" "5" "$turns"
assert_eq "tool_calls_rtmx" "2" "$tool_calls_rtmx"
assert_eq "tool_calls_other" "3" "$tool_calls_other"
assert_eq "backtracks" "1" "$backtracks"

# Planning tokens = cumulative at first Edit (msg 1: 700, msg 2: 750, msg 3: 800 = 2250... wait)
# Actually: cumulative at time of Edit = sum of all tokens up to and including the Edit msg
# msg1: 500+200=700 cumulative, msg2: +750=1450, msg3: +800=2250, msg4 (Edit): +1100=3350
# But planning_tokens = cumulative at first edit = input+output seen so far
# After msg1: 700, msg2: 1450, msg3: 2250, msg4: 3350
# So planning = 3350
# Wait no -- the code sums input and output separately, then at edit time captures the running totals
# input at edit: 500+600+700+800=2600, output at edit: 200+150+100+300=750, total=3350
assert_eq "planning_tokens at first edit" "3350" "$planning_tokens"

# Execution = total - planning = 3950 - 3350 = 600
assert_eq "execution_tokens" "600" "$execution_tokens"

# Test: empty transcript returns zeros
echo "[]" > "$tmpdir/empty.json"
empty_output=$(python3 "$BENCH_DIR/lib/parse_transcript.py" "$tmpdir/empty.json" 2>/dev/null)
read -r e_in e_out e_total _ _ _ e_turns _ _ _ <<< "$empty_output"
assert_eq "empty transcript input=0" "0" "$e_in"
assert_eq "empty transcript turns=0" "0" "$e_turns"

# Test: single message with usage dict
cat > "$tmpdir/single.json" <<'EOF'
{"usage": {"input_tokens": 1000, "output_tokens": 500}}
EOF
single_output=$(python3 "$BENCH_DIR/lib/parse_transcript.py" "$tmpdir/single.json" 2>/dev/null)
read -r s_in s_out s_total _ _ _ _ _ _ _ <<< "$single_output"
assert_eq "single msg input" "1000" "$s_in"
assert_eq "single msg output" "500" "$s_out"
assert_eq "single msg total" "1500" "$s_total"

# Test: invalid JSON fails gracefully
echo "not json" > "$tmpdir/bad.json"
bad_exit=0
python3 "$BENCH_DIR/lib/parse_transcript.py" "$tmpdir/bad.json" 2>/dev/null || bad_exit=$?
assert_eq "invalid JSON exits non-zero" "1" "$bad_exit"

rm -rf "$tmpdir"

# --- Summary ---
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
