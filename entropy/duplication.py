#!/usr/bin/env python3
"""Duplication detection for intent-bearing files.

REQ-ENTROPY-004: Duplication score detects redundant intent across files
via text similarity using paragraph-level Jaccard shingling.
"""

import json
import re
import sys
from itertools import combinations
from pathlib import Path


def extract_paragraphs(text: str, min_words: int = 10) -> list[str]:
    """Extract paragraphs from markdown/text, filtering short ones."""
    # Split on blank lines
    blocks = re.split(r"\n\s*\n", text)
    paragraphs = []
    for block in blocks:
        block = block.strip()
        # Skip code blocks, headers-only, and short blocks
        if block.startswith("```"):
            continue
        if block.startswith("#") and "\n" not in block:
            continue
        if len(block.split()) < min_words:
            continue
        paragraphs.append(block)
    return paragraphs


def shingle(text: str, n: int = 3) -> set[str]:
    """Generate n-gram shingles from text."""
    words = text.lower().split()
    if len(words) < n:
        return set()
    return {" ".join(words[i : i + n]) for i in range(len(words) - n + 1)}


def jaccard_similarity(a: set, b: set) -> float:
    """Compute Jaccard similarity between two sets."""
    if not a or not b:
        return 0.0
    intersection = len(a & b)
    union = len(a | b)
    return intersection / union if union > 0 else 0.0


def find_duplicates(
    files: list[dict], repo_path: str, threshold: float = 0.6
) -> list[dict]:
    """Find duplicate paragraphs across intent-bearing files.

    Args:
        files: list of {"path": str} dicts from scatter scan
        repo_path: root path of the repository
        threshold: Jaccard similarity threshold for flagging duplicates

    Returns:
        list of duplicate pairs with similarity scores
    """
    # Load and extract paragraphs from each file
    file_paragraphs: dict[str, list[tuple[str, set]]] = {}
    for f in files:
        path = Path(repo_path) / f["path"]
        if not path.exists() or not path.is_file():
            continue
        try:
            text = path.read_text(errors="replace")
        except Exception:
            continue
        paragraphs = extract_paragraphs(text)
        if paragraphs:
            file_paragraphs[f["path"]] = [
                (p, shingle(p)) for p in paragraphs
            ]

    # Compare all file pairs
    duplicates = []
    file_paths = list(file_paragraphs.keys())

    for path_a, path_b in combinations(file_paths, 2):
        paras_a = file_paragraphs[path_a]
        paras_b = file_paragraphs[path_b]

        for text_a, shingles_a in paras_a:
            for text_b, shingles_b in paras_b:
                sim = jaccard_similarity(shingles_a, shingles_b)
                if sim >= threshold:
                    duplicates.append(
                        {
                            "file_a": path_a,
                            "file_b": path_b,
                            "paragraph_a": text_a[:200],
                            "paragraph_b": text_b[:200],
                            "similarity": round(sim, 3),
                        }
                    )

    return duplicates


def compute_duplication_score(
    files: list[dict], repo_path: str, threshold: float = 0.6
) -> dict:
    """Compute duplication score for a repository.

    Returns JSON-serializable dict with score and duplicate pairs.
    """
    duplicates = find_duplicates(files, repo_path, threshold)

    # Files involved in at least one duplication
    dup_files = set()
    for d in duplicates:
        dup_files.add(d["file_a"])
        dup_files.add(d["file_b"])

    total_files = len(files)
    duplication_score = len(dup_files) / total_files if total_files > 0 else 0.0

    return {
        "duplication_score": round(duplication_score, 3),
        "duplicate_pairs": len(duplicates),
        "files_with_duplicates": len(dup_files),
        "total_intent_files": total_files,
        "duplicates": duplicates,
    }


def main():
    if len(sys.argv) < 2:
        print("Usage: duplication.py <repo_path> [scatter.json]", file=sys.stderr)
        sys.exit(1)

    repo_path = sys.argv[1]

    # Read scatter JSON from stdin or file
    if len(sys.argv) > 2:
        scatter_data = json.loads(Path(sys.argv[2]).read_text())
    else:
        scatter_data = json.load(sys.stdin)

    files = scatter_data.get("files", [])
    result = compute_duplication_score(files, repo_path)

    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
