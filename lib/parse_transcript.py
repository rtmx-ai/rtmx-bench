#!/usr/bin/env python3
"""Parse Claude Code session transcripts for token accounting.

REQ-HARNESS-002: Token accounting extracts per-session counts with RTMX attribution.

Extracts token counts, RTMX tool attribution, planning vs execution phases,
and backtrack detection from Claude Code JSON transcripts.
"""

import json
import sys
from pathlib import Path

# RTMX MCP tool names (matched by prefix)
RTMX_TOOL_PREFIXES = (
    "mcp__rtmx__",
    "rtmx_",
)


def is_rtmx_tool(tool_name: str) -> bool:
    """Check if a tool call is an RTMX MCP tool."""
    return any(tool_name.startswith(prefix) for prefix in RTMX_TOOL_PREFIXES)


def is_code_edit_tool(tool_name: str) -> bool:
    """Check if a tool call is a code editing operation."""
    return tool_name in ("Edit", "Write", "NotebookEdit")


def estimate_token_size(content: str) -> int:
    """Rough token estimate: ~4 chars per token."""
    return max(1, len(content) // 4)


def load_transcript(path: str):
    """Load transcript from JSON array, single JSON object, or NDJSON (stream-json).

    Returns a list of message dicts.
    """
    text = Path(path).read_text().strip()
    if not text:
        return []

    # Try JSON array or single object first
    try:
        data = json.loads(text)
        if isinstance(data, list):
            return data
        if isinstance(data, dict):
            if "messages" in data:
                return data["messages"]
            # Single summary object (--output-format json) -- wrap as list
            return [data]
        return []
    except json.JSONDecodeError:
        pass

    # NDJSON (--output-format stream-json): one JSON object per line
    messages = []
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            messages.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    if not messages:
        raise json.JSONDecodeError("No valid JSON found", text, 0)
    return messages


def parse_transcript(path: str) -> dict:
    """Parse a Claude Code transcript and extract token metrics.

    Returns a dict with all token accounting fields.
    """
    messages = load_transcript(path)

    result = {
        "input_tokens": 0,
        "output_tokens": 0,
        "total_tokens": 0,
        "rtmx_tokens": 0,
        "planning_tokens": 0,
        "execution_tokens": 0,
        "turns": 0,
        "backtracks": 0,
        "tool_calls_rtmx": 0,
        "tool_calls_other": 0,
        "rtmx_tool_breakdown": {},
    }

    first_edit_seen = False
    files_read = set()  # Track files read to detect backtracks
    has_result_summary = False
    # Per-turn accumulators for planning/execution split
    cumulative_input = 0
    cumulative_output = 0
    cumulative_tokens_at_first_edit = 0
    turn_count = 0

    for raw in messages:
        if not isinstance(raw, dict):
            continue

        # Normalize stream-json envelope: {"type":"assistant","message":{...}}
        # vs. direct message format: {"role":"assistant","content":[...],"usage":{}}
        msg_type = raw.get("type", "")
        if msg_type in ("assistant", "user") and "message" in raw:
            msg = raw["message"]
        elif msg_type == "result" and "usage" in raw:
            # Use the first (main session) result -- stream-json may emit
            # multiple result messages for sub-agents/tasks
            if has_result_summary:
                continue
            has_result_summary = True
            usage = raw.get("usage", {})
            cache_input = usage.get("cache_creation_input_tokens", 0) + \
                usage.get("cache_read_input_tokens", 0)
            result["input_tokens"] = usage.get("input_tokens", 0) + cache_input
            result["output_tokens"] = usage.get("output_tokens", 0)
            result["turns"] = raw.get("num_turns", turn_count)
            continue
        elif "role" in raw:
            msg = raw
        elif "usage" in raw and not msg_type:
            # Bare usage dict (e.g. single message with no role/type)
            usage = raw["usage"]
            cumulative_input += usage.get("input_tokens", 0)
            cumulative_output += usage.get("output_tokens", 0)
            continue
        else:
            continue

        # Count turns (assistant messages)
        role = msg.get("role", "")
        if role == "assistant":
            turn_count += 1

        # Extract per-turn usage
        usage = msg.get("usage", {})
        msg_input = usage.get("input_tokens", 0)
        msg_output = usage.get("output_tokens", 0)
        cumulative_input += msg_input
        cumulative_output += msg_output

        # Process tool calls
        content = msg.get("content", [])
        if isinstance(content, str):
            continue

        for block in content:
            if not isinstance(block, dict):
                continue

            # Tool use blocks
            if block.get("type") == "tool_use":
                tool_name = block.get("name", "")

                if is_rtmx_tool(tool_name):
                    result["tool_calls_rtmx"] += 1
                    # Track per-tool breakdown
                    short_name = tool_name.split("__")[-1] if "__" in tool_name else tool_name
                    result["rtmx_tool_breakdown"][short_name] = (
                        result["rtmx_tool_breakdown"].get(short_name, 0) + 1
                    )
                else:
                    result["tool_calls_other"] += 1

                # Detect first code edit for planning/execution split
                if not first_edit_seen and is_code_edit_tool(tool_name):
                    first_edit_seen = True
                    cumulative_tokens_at_first_edit = (
                        cumulative_input + cumulative_output
                    )

                # Detect backtracks: reading a file that was already read
                if tool_name == "Read":
                    file_path = ""
                    tool_input = block.get("input", {})
                    if isinstance(tool_input, dict):
                        file_path = tool_input.get("file_path", "")
                    if file_path in files_read:
                        result["backtracks"] += 1
                    else:
                        files_read.add(file_path)

    # Use per-turn sums if no result summary was found (old format / tests)
    if not has_result_summary:
        result["input_tokens"] = cumulative_input
        result["output_tokens"] = cumulative_output
        result["turns"] = turn_count

    result["total_tokens"] = result["input_tokens"] + result["output_tokens"]

    if first_edit_seen:
        result["planning_tokens"] = cumulative_tokens_at_first_edit
        result["execution_tokens"] = result["total_tokens"] - cumulative_tokens_at_first_edit
    else:
        # No edits made -- all tokens are planning
        result["planning_tokens"] = result["total_tokens"]
        result["execution_tokens"] = 0

    return result


def main():
    if len(sys.argv) != 2:
        print("Usage: parse_transcript.py <transcript.json>", file=sys.stderr)
        sys.exit(1)

    path = sys.argv[1]
    try:
        result = parse_transcript(path)
    except (json.JSONDecodeError, FileNotFoundError) as e:
        print(f"ERROR: Failed to parse transcript: {e}", file=sys.stderr)
        # Output zeros so the harness can continue
        print("0 0 0 0 0 0 0 0 0 0")
        sys.exit(1)

    # Output space-separated for shell consumption
    print(
        f"{result['input_tokens']} "
        f"{result['output_tokens']} "
        f"{result['total_tokens']} "
        f"{result['rtmx_tokens']} "
        f"{result['planning_tokens']} "
        f"{result['execution_tokens']} "
        f"{result['turns']} "
        f"{result['backtracks']} "
        f"{result['tool_calls_rtmx']} "
        f"{result['tool_calls_other']}"
    )

    # Also output detailed JSON to stderr for logging
    print(json.dumps(result, indent=2), file=sys.stderr)


if __name__ == "__main__":
    main()
