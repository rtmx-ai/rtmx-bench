# REQ-ENTROPY-007: Dependency Directory Exclusion

## Summary

The entropy scatter scanner must exclude language-specific dependency
directories (node_modules, .venv, vendor, target, __pycache__) from
intent-bearing file discovery. Without this exclusion, the scatter score
measures dependency tree size rather than project organization quality.

## Motivation

Observed in rtmx-bench task-manager experiments: every Node.js project
scores entropy=5.0 because node_modules/ contains ~472 README.md files
that inflate scatter_score to maximum. Every Python project scores 0.0.
The metric is a proxy for language choice, not project quality.

## Acceptance Criteria

1. entropy/scan.sh excludes the following directories from file discovery:
   - node_modules
   - .venv / venv
   - vendor
   - target
   - __pycache__
   - .git (already excluded)

2. bench.sh creates a .gitignore in agent workdirs before running
   `git add -A` so that dependency directories are not committed.

3. Scatter scores for equivalent projects in different languages produce
   comparable values (not 0.0 vs 5.0 based on language alone).

4. Existing entropy tests continue to pass.

## Files to Modify

- entropy/scan.sh -- add exclusion globs to both git ls-files and find paths
- bench.sh -- write .gitignore before git init in entropy measurement block
- tests/test_entropy.sh -- add test verifying node_modules exclusion

## Dependencies

- REQ-ENTROPY-001 (scatter scanner)
- REQ-ENTROPY-006 (entropy pipeline)
