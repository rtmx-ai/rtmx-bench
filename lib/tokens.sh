#!/usr/bin/env bash
# tokens.sh -- Token extraction and attribution from Claude Code transcripts
# REQ-HARNESS-002: Token accounting extracts per-session counts with RTMX attribution
set -euo pipefail

# Extract token counts from a Claude Code session transcript
# Args: transcript_path
# Output: space-separated values:
#   input_tokens output_tokens total_tokens rtmx_tokens planning_tokens
#   execution_tokens turns backtracks tool_calls_rtmx tool_calls_other
extract_tokens() {
    local transcript="${1:?Usage: extract_tokens <transcript_path>}"

    if [[ ! -f "$transcript" ]]; then
        echo "ERROR: Transcript not found: $transcript" >&2
        echo "0 0 0 0 0 0 0 0 0 0"
        return 1
    fi

    python3 "$SCRIPT_DIR/parse_transcript.py" "$transcript"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
