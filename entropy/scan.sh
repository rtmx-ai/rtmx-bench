#!/usr/bin/env bash
# scan.sh -- Knowledge entropy scatter scanner
# REQ-ENTROPY-001: Scatter score counts intent-bearing files across repo directories
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATTERNS_FILE="${SCRIPT_DIR}/patterns.txt"

# Discover intent-bearing files in a repository
# Args: repo_path
# Output: JSON with scatter_score, scatter_depth, inline_markers, files
entropy_scan() {
    local repo_path="${1:?Usage: entropy_scan <repo_path>}"

    if [[ ! -d "$repo_path" ]]; then
        echo "ERROR: Not a directory: $repo_path" >&2
        return 1
    fi

    if [[ ! -f "$PATTERNS_FILE" ]]; then
        echo "ERROR: Patterns file not found: $PATTERNS_FILE" >&2
        return 1
    fi

    local intent_files=()
    local dirs_seen=()

    # REQ-ENTROPY-007: Dependency directories to exclude from scanning
    local exclude_dirs=(node_modules .venv venv vendor target __pycache__ .git)

    # Read patterns and find matching files
    while IFS= read -r pattern; do
        # Skip comments and empty lines
        [[ -z "$pattern" || "$pattern" == \#* ]] && continue

        # Use git ls-files to respect .gitignore; fall back to find for non-git dirs
        local find_cmd
        if git -C "$repo_path" rev-parse --git-dir &>/dev/null; then
            find_cmd() {
                cd "$repo_path" && git ls-files -z -- "$pattern" 2>/dev/null \
                    | while IFS= read -r -d '' f; do
                        local skip=0
                        for excl in "${exclude_dirs[@]}"; do
                            case "$f" in "$excl/"*|*"/$excl/"*) skip=1; break ;; esac
                        done
                        [[ $skip -eq 0 ]] && printf '%s\0' "$f"
                    done
            }
        else
            # Build find prune arguments for dependency directories
            local prune_args=()
            for excl in "${exclude_dirs[@]}"; do
                prune_args+=(-path "./$excl" -prune -o)
            done
            find_cmd() { cd "$repo_path" && find . "${prune_args[@]}" -path "$pattern" -print0 2>/dev/null; }
        fi

        while IFS= read -r -d '' file; do
            # Deduplicate
            local already=0
            for existing in "${intent_files[@]+"${intent_files[@]}"}"; do
                if [[ "$existing" == "$file" ]]; then
                    already=1
                    break
                fi
            done
            [[ $already -eq 1 ]] && continue

            intent_files+=("$file")

            # Track unique directories
            local dir
            dir=$(dirname "$file")
            local dir_seen=0
            for d in "${dirs_seen[@]+"${dirs_seen[@]}"}"; do
                if [[ "$d" == "$dir" ]]; then
                    dir_seen=1
                    break
                fi
            done
            [[ $dir_seen -eq 0 ]] && dirs_seen+=("$dir")
        done < <(find_cmd)
    done < "$PATTERNS_FILE"

    # Count inline intent markers (TODO, FIXME, HACK, XXX) in source files
    local inline_markers=0
    if command -v rg &>/dev/null; then
        inline_markers=$(cd "$repo_path" && rg -c '\b(TODO|FIXME|HACK|XXX)\b' \
            --type-not binary \
            --glob '!.git' \
            --glob '!vendor' \
            --glob '!node_modules' \
            2>/dev/null | awk -F: '{s+=$2} END {print s+0}')
    else
        inline_markers=$(cd "$repo_path" && grep -r -c -E '\b(TODO|FIXME|HACK|XXX)\b' \
            --include='*.go' --include='*.py' --include='*.ts' --include='*.js' \
            --include='*.rs' --include='*.java' --include='*.rb' --include='*.sh' \
            --exclude-dir=.git --exclude-dir=vendor --exclude-dir=node_modules \
            2>/dev/null | awk -F: '{s+=$2} END {print s+0}')
    fi

    local scatter_score=${#intent_files[@]}
    local scatter_depth=${#dirs_seen[@]}

    # Build JSON output
    local files_json="["
    local first=1
    for file in "${intent_files[@]+"${intent_files[@]}"}"; do
        local abs_file="$repo_path/$file"
        local size=0
        local last_modified=""

        if [[ -f "$abs_file" ]]; then
            size=$(wc -c < "$abs_file" | tr -d ' ')
            if git -C "$repo_path" log -1 --format="%aI" -- "$file" &>/dev/null; then
                last_modified=$(git -C "$repo_path" log -1 --format="%aI" -- "$file" 2>/dev/null || echo "unknown")
            else
                last_modified="untracked"
            fi
        fi

        [[ $first -eq 0 ]] && files_json+=","
        first=0
        files_json+="{\"path\":\"$file\",\"size\":$size,\"last_modified\":\"$last_modified\"}"
    done
    files_json+="]"

    cat <<EOF
{
  "scatter_score": $scatter_score,
  "scatter_depth": $scatter_depth,
  "inline_markers": $inline_markers,
  "files": $files_json
}
EOF
}

# Pretty-print scan results
entropy_scan_report() {
    local repo_path="${1:?Usage: entropy_scan_report <repo_path>}"
    local json
    json=$(entropy_scan "$repo_path")

    local scatter_score scatter_depth inline_markers
    scatter_score=$(echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin)['scatter_score'])")
    scatter_depth=$(echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin)['scatter_depth'])")
    inline_markers=$(echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin)['inline_markers'])")

    echo "=== Knowledge Entropy: Scatter ==="
    echo ""
    echo "  Intent-bearing files: $scatter_score"
    echo "  Across directories:   $scatter_depth"
    echo "  Inline markers:       $inline_markers (TODO/FIXME/HACK/XXX)"
    echo ""
    echo "Files:"
    echo "$json" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for f in data['files']:
    size_kb = f['size'] / 1024
    print(f\"  {f['path']:50s} {size_kb:6.1f} KB  {f['last_modified']}\")
"
}

# Subcommand dispatch
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    cmd="${1:-report}"
    shift || true
    case "$cmd" in
        scan)   entropy_scan "$@" ;;
        report) entropy_scan_report "$@" ;;
        help)
            echo "Usage: scan.sh <command> <repo_path>"
            echo "Commands:"
            echo "  scan <path>    Output JSON scatter data"
            echo "  report <path>  Pretty-print scatter report"
            ;;
        *)
            echo "Unknown command: $cmd" >&2
            exit 1
            ;;
    esac
fi
