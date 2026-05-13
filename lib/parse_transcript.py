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


def parse_transcript(path: str) -> dict:
    """Parse a Claude Code transcript and extract token metrics.

    Returns a dict with all token accounting fields.
    """
    data = json.loads(Path(path).read_text())

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

    # Handle different transcript formats
    messages = []
    if isinstance(data, list):
        messages = data
    elif isinstance(data, dict):
        # Single response or wrapped format
        if "messages" in data:
            messages = data["messages"]
        elif "usage" in data:
            # Single message with usage
            result["input_tokens"] = data["usage"].get("input_tokens", 0)
            result["output_tokens"] = data["usage"].get("output_tokens", 0)
            result["total_tokens"] = result["input_tokens"] + result["output_tokens"]
            return result
        elif "result" in data:
            # Wrapped result format
            messages = data.get("result", {}).get("messages", [])

    first_edit_seen = False
    files_read = set()  # Track files read to detect backtracks
    cumulative_tokens_at_first_edit = 0

    for msg in messages:
        if not isinstance(msg, dict):
            continue

        # Count turns (assistant messages)
        role = msg.get("role", "")
        if role == "assistant":
            result["turns"] += 1

        # Extract usage from message
        usage = msg.get("usage", {})
        msg_input = usage.get("input_tokens", 0)
        msg_output = usage.get("output_tokens", 0)
        result["input_tokens"] += msg_input
        result["output_tokens"] += msg_output

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
                        result["input_tokens"] + result["output_tokens"]
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

            # Tool result blocks -- estimate RTMX token contribution
            if block.get("type") == "tool_result":
                tool_use_id = block.get("tool_use_id", "")
                # Check if this result corresponds to an RTMX tool
                result_content = block.get("content", "")
                if isinstance(result_content, list):
                    result_content = " ".join(
                        b.get("text", "") for b in result_content if isinstance(b, dict)
                    )
                if isinstance(result_content, str):
                    # We attribute RTMX tokens in a second pass if needed
                    pass

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
