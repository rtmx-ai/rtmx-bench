#!/usr/bin/env python3
"""Tests for duplication detection and composite entropy score.

REQ-ENTROPY-004: Duplication score
REQ-ENTROPY-005: Composite entropy score
"""

import json
import os
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "entropy"))
import duplication
import normalize


def test_extract_paragraphs():
    """Test paragraph extraction from markdown."""
    text = """# Header

This is a paragraph with enough words to be meaningful
and should be extracted as a complete block of text.

```python
code_block = "should be skipped"
```

# Another Header

This is another paragraph that has enough words to pass
the minimum word count filter for extraction.

Short.
"""
    paras = duplication.extract_paragraphs(text)
    assert len(paras) == 2, f"Expected 2 paragraphs, got {len(paras)}"
    assert "paragraph with enough" in paras[0]
    assert "another paragraph" in paras[1]
    print("  [PASS] extract_paragraphs")


def test_shingle():
    """Test n-gram shingling."""
    shingles = duplication.shingle("the quick brown fox jumps")
    assert "the quick brown" in shingles
    assert "quick brown fox" in shingles
    assert len(shingles) == 3  # 5 words, 3-grams = 3 shingles
    print("  [PASS] shingle")


def test_shingle_short():
    """Test shingling with text shorter than n."""
    shingles = duplication.shingle("too short")
    assert len(shingles) == 0
    print("  [PASS] shingle_short")


def test_jaccard_identical():
    """Test Jaccard similarity with identical sets."""
    a = {"a", "b", "c"}
    sim = duplication.jaccard_similarity(a, a)
    assert sim == 1.0
    print("  [PASS] jaccard_identical")


def test_jaccard_disjoint():
    """Test Jaccard similarity with disjoint sets."""
    sim = duplication.jaccard_similarity({"a", "b"}, {"c", "d"})
    assert sim == 0.0
    print("  [PASS] jaccard_disjoint")


def test_jaccard_partial():
    """Test Jaccard similarity with partial overlap."""
    sim = duplication.jaccard_similarity({"a", "b", "c"}, {"b", "c", "d"})
    assert 0.4 < sim < 0.6  # 2/4 = 0.5
    print("  [PASS] jaccard_partial")


def test_find_duplicates():
    """Test finding duplicates across files."""
    tmpdir = tempfile.mkdtemp()
    # Two files with the same paragraph
    shared_text = "This is a shared paragraph with enough words to be meaningful and should trigger duplication detection when compared across two files"
    Path(tmpdir, "README.md").write_text(f"# Project\n\n{shared_text}\n\nUnique to README.")
    Path(tmpdir, "DESIGN.md").write_text(f"# Design\n\n{shared_text}\n\nUnique to DESIGN.")

    files = [{"path": "README.md"}, {"path": "DESIGN.md"}]
    dups = duplication.find_duplicates(files, tmpdir, threshold=0.5)
    assert len(dups) > 0, "Should find at least one duplicate pair"
    assert dups[0]["similarity"] > 0.5
    print("  [PASS] find_duplicates")


def test_duplication_score():
    """Test duplication score computation."""
    tmpdir = tempfile.mkdtemp()
    Path(tmpdir, "a.md").write_text("# A\n\nUnique content only found in file A with enough words to be a real paragraph.")
    Path(tmpdir, "b.md").write_text("# B\n\nCompletely different content only in file B with enough words for paragraph extraction.")

    files = [{"path": "a.md"}, {"path": "b.md"}]
    result = duplication.compute_duplication_score(files, tmpdir)
    assert result["duplication_score"] == 0.0  # no duplicates
    assert result["duplicate_pairs"] == 0
    print("  [PASS] duplication_score_no_dups")


def test_normalize_scatter():
    """Test scatter normalization."""
    assert normalize.normalize(1, "scatter") == 0.0
    assert normalize.normalize(20, "scatter") == 1.0
    assert 0.4 < normalize.normalize(10, "scatter") < 0.6  # ~0.47
    print("  [PASS] normalize_scatter")


def test_normalize_staleness():
    """Test staleness normalization."""
    assert normalize.normalize(0.0, "staleness") == 0.0
    assert normalize.normalize(1.0, "staleness") == 1.0
    assert normalize.normalize(0.5, "staleness") == 0.5
    print("  [PASS] normalize_staleness")


def test_composite_all_dimensions():
    """Test composite score with all dimensions available."""
    result = normalize.compute_composite({
        "scatter": 10,
        "staleness": 0.5,
        "navigability": 5,
        "duplication": 0.25,
    })
    assert 0 <= result["entropy_score"] <= 10
    assert result["dimensions_included"] == 4
    assert len(result["dimensions_excluded"]) == 0
    print(f"  [PASS] composite_all_dimensions (score={result['entropy_score']})")


def test_composite_partial_dimensions():
    """Test composite score with missing dimensions."""
    result = normalize.compute_composite({
        "scatter": 15,
        "staleness": 0.8,
        "navigability": None,
        "duplication": None,
    })
    assert 0 <= result["entropy_score"] <= 10
    assert result["dimensions_included"] == 2
    assert "navigability" in result["dimensions_excluded"]
    assert "duplication" in result["dimensions_excluded"]
    print(f"  [PASS] composite_partial_dimensions (score={result['entropy_score']})")


def test_composite_zero_entropy():
    """Test that minimal values produce zero entropy."""
    result = normalize.compute_composite({
        "scatter": 0,
        "staleness": 0.0,
        "navigability": 0,
        "duplication": 0.0,
    })
    assert result["entropy_score"] == 0.0
    print("  [PASS] composite_zero_entropy")


def test_composite_max_entropy():
    """Test that maximal values produce max entropy."""
    result = normalize.compute_composite({
        "scatter": 30,
        "staleness": 1.0,
        "navigability": 15,
        "duplication": 0.8,
    })
    assert result["entropy_score"] == 10.0
    print("  [PASS] composite_max_entropy")


def main():
    print("=== Duplication Detection Tests ===")
    tests_dup = [
        test_extract_paragraphs,
        test_shingle,
        test_shingle_short,
        test_jaccard_identical,
        test_jaccard_disjoint,
        test_jaccard_partial,
        test_find_duplicates,
        test_duplication_score,
    ]

    print("\n=== Composite Entropy Score Tests ===")
    tests_norm = [
        test_normalize_scatter,
        test_normalize_staleness,
        test_composite_all_dimensions,
        test_composite_partial_dimensions,
        test_composite_zero_entropy,
        test_composite_max_entropy,
    ]

    passed = 0
    failed = 0
    for test in tests_dup + tests_norm:
        try:
            test()
            passed += 1
        except Exception as e:
            print(f"  [FAIL] {test.__name__}: {e}")
            failed += 1

    print(f"\n=== Results: {passed} passed, {failed} failed ===")
    sys.exit(0 if failed == 0 else 1)


if __name__ == "__main__":
    main()
