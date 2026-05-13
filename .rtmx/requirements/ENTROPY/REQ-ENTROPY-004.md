# REQ-ENTROPY-004: Duplication Score

## Status: MISSING
## Priority: MEDIUM
## Phase: 3

## Requirement

rtmx-bench shall compute a duplication score measuring how much project
intent is redundantly stated across multiple files, creating drift risk.

## Rationale

When the same requirement, feature description, or architectural decision
appears in both README.md and docs/architecture.md, one will eventually
drift. An agent reading both gets contradictory signals. Duplication is
the mechanism by which scatter becomes actively harmful rather than
merely inefficient.

Unlike scatter and staleness, duplication detection requires content
comparison -- either textual similarity or semantic similarity via
embeddings. This makes it more expensive to compute but more precise
in identifying actual risk.

## Acceptance Criteria

1. For each pair of intent-bearing files, computes textual overlap
   using paragraph-level comparison:
   - Extracts paragraphs (blocks separated by blank lines)
   - Computes Jaccard similarity on 3-gram shingles between paragraphs
   - Paragraph pairs with similarity > 0.6 are flagged as duplicates
2. Reports duplicate pairs: file_a, file_b, paragraph_a, paragraph_b,
   similarity_score
3. Computes duplication_score = count(files with at least one
   duplicate paragraph) / count(all intent files)
4. Optionally uses an LLM to classify duplicates as:
   - IDENTICAL: same information, same wording
   - PARAPHRASE: same information, different wording
   - CONTRADICTORY: same topic, conflicting claims
   (LLM mode enabled via `--llm` flag, disabled by default)
5. Without `--llm`, uses pure textual similarity (no API calls needed)
6. Outputs structured JSON merged with other entropy scores

## Dependencies

- REQ-ENTROPY-001: Scatter score (provides the file list to compare)

## Files to Create

- `entropy/duplication.py` -- paragraph extraction, shingling, similarity
  (Python for text processing -- shell is insufficient)
