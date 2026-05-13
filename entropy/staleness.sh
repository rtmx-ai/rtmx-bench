#!/usr/bin/env bash
# staleness.sh -- Git history staleness analysis for intent-bearing files
# REQ-ENTROPY-002: Staleness score measures documentation age vs code activity
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scan.sh"

# Compute staleness score for a repository
# Args: repo_path
# Output: JSON with per-file staleness and aggregate score
entropy_staleness() {
    local repo_path="${1:?Usage: entropy_staleness <repo_path>}"

    if ! git -C "$repo_path" rev-parse --git-dir &>/dev/null; then
        echo "ERROR: Not a git repository: $repo_path" >&2
        return 1
    fi

    # Get scatter data first
    local scatter_json
    scatter_json=$(entropy_scan "$repo_path")

    # Get most recent commit date in the repo (repo activity baseline)
    local repo_latest_epoch
    repo_latest_epoch=$(git -C "$repo_path" log -1 --format="%at" 2>/dev/null || echo 0)
    local now_epoch
    now_epoch=$(date +%s)

    # If repo has no commits, nothing to measure
    if [[ "$repo_latest_epoch" -eq 0 ]]; then
        cat <<EOF
{
  "staleness_score": 0,
  "stale_count": 0,
  "abandoned_count": 0,
  "total_intent_files": 0,
  "repo_latest_commit": "none",
  "files": []
}
EOF
        return 0
    fi

    local repo_latest_date
    repo_latest_date=$(git -C "$repo_path" log -1 --format="%aI" 2>/dev/null)

    # Compute days since most recent repo activity
    local repo_age_days=$(( (now_epoch - repo_latest_epoch) / 86400 ))
    # Use 1 as minimum to avoid division by zero
    [[ $repo_age_days -lt 1 ]] && repo_age_days=1

    # Get average commit frequency (commits per day over last 90 days)
    local recent_commits
    recent_commits=$(git -C "$repo_path" rev-list --count --since="90 days ago" HEAD 2>/dev/null || echo 0)

    # Process each intent file
    local files_json="["
    local first=1
    local stale_count=0
    local abandoned_count=0
    local total_files=0

    # Extract file paths from scatter JSON
    local file_paths
    file_paths=$(echo "$scatter_json" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for f in data['files']:
    print(f['path'])
" 2>/dev/null)

    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        total_files=$((total_files + 1))

        local file_epoch=0
        local file_date="untracked"
        local classification="CURRENT"
        local staleness_ratio="0.0"

        # Get file's last modification date from git
        file_epoch=$(git -C "$repo_path" log -1 --format="%at" -- "$file" 2>/dev/null || echo 0)

        if [[ "$file_epoch" -eq 0 ]]; then
            classification="UNTRACKED"
            total_files=$((total_files - 1))  # exclude from scoring
        else
            file_date=$(git -C "$repo_path" log -1 --format="%aI" -- "$file" 2>/dev/null)
            local file_age_days=$(( (now_epoch - file_epoch) / 86400 ))
            [[ $file_age_days -lt 1 ]] && file_age_days=1

            # staleness_ratio = file_age / repo_age
            # Higher means the file is disproportionately old relative to repo activity
            staleness_ratio=$(python3 -c "print(round($file_age_days / $repo_age_days, 2))")

            # Classify
            local ratio_int
            ratio_int=$(python3 -c "print(int($staleness_ratio))")
            if [[ "$ratio_int" -ge 10 ]]; then
                classification="ABANDONED"
                abandoned_count=$((abandoned_count + 1))
            elif [[ "$ratio_int" -ge 3 ]]; then
                classification="STALE"
                stale_count=$((stale_count + 1))
            fi
        fi

        [[ $first -eq 0 ]] && files_json+=","
        first=0
        files_json+="{\"path\":\"$file\",\"last_modified\":\"$file_date\",\"staleness_ratio\":$staleness_ratio,\"classification\":\"$classification\"}"
    done <<< "$file_paths"
    files_json+="]"

    # Aggregate staleness score: proportion of stale+abandoned files
    local staleness_score="0.0"
    if [[ $total_files -gt 0 ]]; then
        staleness_score=$(python3 -c "print(round(($stale_count + $abandoned_count) / $total_files, 3))")
    fi

    cat <<EOF
{
  "staleness_score": $staleness_score,
  "stale_count": $stale_count,
  "abandoned_count": $abandoned_count,
  "total_intent_files": $total_files,
  "repo_latest_commit": "$repo_latest_date",
  "recent_commits_90d": $recent_commits,
  "files": $files_json
}
EOF
}

# Pretty-print staleness results
entropy_staleness_report() {
    local repo_path="${1:?Usage: entropy_staleness_report <repo_path>}"
    local json
    json=$(entropy_staleness "$repo_path")

    echo "=== Knowledge Entropy: Staleness ==="
    echo ""
    echo "$json" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(f\"  Staleness score:     {data['staleness_score']:.1%}\")
print(f\"  Stale files:         {data['stale_count']}\")
print(f\"  Abandoned files:     {data['abandoned_count']}\")
print(f\"  Total intent files:  {data['total_intent_files']}\")
print(f\"  Recent commits (90d): {data['recent_commits_90d']}\")
print()
print('Files:')
for f in data['files']:
    marker = {'CURRENT': ' ', 'STALE': '!', 'ABANDONED': 'X', 'UNTRACKED': '?'}[f['classification']]
    print(f\"  [{marker}] {f['path']:50s} ratio={f['staleness_ratio']:5.1f}  {f['classification']}\")
"
}

# Subcommand dispatch
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    cmd="${1:-report}"
    shift || true
    case "$cmd" in
        scan)   entropy_staleness "$@" ;;
        report) entropy_staleness_report "$@" ;;
        help)
            echo "Usage: staleness.sh <command> <repo_path>"
            echo "Commands:"
            echo "  scan <path>    Output JSON staleness data"
            echo "  report <path>  Pretty-print staleness report"
            ;;
        *)
            echo "Unknown command: $cmd" >&2
            exit 1
            ;;
    esac
fi
