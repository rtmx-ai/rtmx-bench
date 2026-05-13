# REQ-DATA-002: Reproducibility Framework

## Status: MISSING
## Priority: HIGH
## Phase: 2

## Requirement

rtmx-bench shall provide a self-contained reproducibility framework
that allows any researcher to replicate experiments, add their own
projects, and contribute results back.

## Rationale

A benchmark is only credible if others can reproduce it. The framework
must minimize setup friction: clone the repo, install minimal
dependencies, run one command. It must also be extensible -- the value
of the benchmark grows with the number of projects and experiments
contributed by the community.

## Acceptance Criteria

1. `README.md` documents the complete methodology:
   - Hypothesis being tested
   - Experimental design (control vs treatment)
   - How to run experiments
   - How to interpret results
   - How to add a new experiment
2. `make setup` installs all dependencies (rtmx CLI, Python analysis
   packages, Claude Code) and validates the environment
3. `make run-all` executes all experiments with default settings
   (N=5 runs per condition)
4. `make analyze` runs analysis on collected results
5. Adding a new experiment requires only:
   - A prompt file in `prompts/`
   - An experiment config in `experiments/`
   - A fixture directory in `fixtures/` (treatment condition only)
   - No changes to harness code
6. `CONTRIBUTING.md` documents how to contribute new experiments
   and submit results
7. Results from different environments (model versions, hardware,
   dates) are disambiguated by the metadata columns in the ledger
8. The repo includes a `.github/workflows/ci.yml` that validates
   experiment configurations and runs `--dry-run` on each experiment
9. License: Apache 2.0 (matching RTMX)

## Dependencies

- REQ-HARNESS-001: Experiment runner
- REQ-HARNESS-005: Statistical analysis
- REQ-DATA-001: Ledger format

## Files to Create

- `README.md` -- methodology and usage documentation
- `CONTRIBUTING.md` -- how to add experiments
- `Makefile` -- setup, run-all, analyze targets
- `.github/workflows/ci.yml` -- config validation
