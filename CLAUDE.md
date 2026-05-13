# CLAUDE.md

This file provides guidance to Claude Code when working with the rtmx-bench codebase.

## Overview

rtmx-bench is an open-source benchmark harness for measuring whether structured
requirements traceability (via RTMX) reduces agent token consumption per completed
software engineering task. It also introduces a knowledge entropy metric for
quantifying project organization quality.

## Quick Commands

```bash
make setup        # Install dependencies, validate environment
make run-all      # Run all experiments (N=5 per condition)
make analyze      # Statistical analysis on collected results
make charts       # Generate visualizations
make entropy      # Run entropy scanner on a repo
make validate     # Validate experiment configs and ledger schema
```

## Project Structure

```
rtmx-bench/
  bench.sh              -- main experiment runner
  lib/                   -- shell library functions
    setup.sh             -- project clone and RTMX seeding
    capture.sh           -- transcript and token extraction
    csv.sh               -- ledger row construction and validation
    verify.sh            -- test execution and outcome classification
    tokens.sh            -- token extraction from transcripts
  entropy/               -- knowledge entropy scanner
    scan.sh              -- file discovery and scatter scoring
    staleness.sh         -- git history staleness analysis
    navigability.sh      -- agent probe sessions
    duplication.py       -- textual similarity analysis
    score.sh             -- composite entropy scoring
    normalize.py         -- dimension normalization
    patterns.txt         -- intent-bearing filename patterns
  analysis/              -- statistical analysis and visualization
    compare.py           -- significance tests, amortization curves
    plot.py              -- chart generation
    style.py             -- chart styling
    requirements.txt     -- Python dependencies
  prompts/               -- task prompts (identical for both conditions)
  experiments/           -- experiment configuration files
  fixtures/              -- pre-built RTM databases (treatment condition)
  results/
    raw/                 -- session transcripts (gitignored)
    charts/              -- generated visualizations
    summary.csv          -- the data ledger
  docs/                  -- methodology and schema documentation
  tests/                 -- harness and entropy tests
```

## Development Workflow

1. Check `rtmx backlog` for prioritized requirements
2. Write failing tests (TDD Red)
3. Implement minimal code to pass (TDD Green)
4. Run `make validate`
5. Run `rtmx verify --update`

## Key Design Decisions

1. Shell-first harness -- minimal dependencies, runs anywhere with bash + Claude Code
2. Python for analysis only -- scipy/pandas for statistics, matplotlib for charts
3. CSV ledger as single source of truth -- append-only, schema-validated
4. Experiments are configuration, not code -- adding an experiment requires no harness changes

## Testing

```bash
make test          # Run all tests
make test-harness  # Test experiment runner
make test-entropy  # Test entropy scanner
make test-data     # Test ledger validation
```

## Dependencies

Runtime: bash 4+, Claude Code, git, python3
Analysis: scipy, pandas, matplotlib (installed via `make setup`)
Optional: rtmx CLI (for treatment condition seeding)
