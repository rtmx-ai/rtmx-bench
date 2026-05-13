# rtmx-bench

Benchmark harness for measuring whether structured requirements traceability
reduces AI agent token consumption per completed software engineering task.

## Hypothesis

Agents using RTMX (a requirements traceability matrix) consume fewer total
tokens per completed task than agents navigating unstructured project
documentation. The planning overhead of maintaining structured requirements
is amortized across tasks and offset by reduced exploration, backtracking,
and wasted reasoning.

## Methodology

### Experimental Design

Each experiment is an A/B test with two conditions:

- **Control**: The agent receives a task prompt and a project directory.
  No RTMX artifacts or MCP tools are present. The agent must discover
  project structure, requirements, and dependencies by reading code and
  documentation.

- **Treatment**: The agent receives the identical task prompt and the same
  project directory, but with an RTMX database (.rtmx/database.csv) and
  MCP tools pre-configured. The agent can call `status`, `next`, `backlog`,
  `deps`, and other tools to query structured project knowledge.

The only variable is RTMX presence. The prompt is identical (verified by
SHA-256 hash). The model is identical. Both conditions run N times to
account for stochastic variance in model output.

### Measurements

**Primary metric**: Token efficiency ratio

    ratio = mean_tokens(control) / mean_tokens(treatment)

A ratio > 1.0 means RTMX saves tokens. A ratio < 1.0 means it adds overhead.

**Secondary metrics**:
- Completion rate (PASS outcomes / total runs)
- Planning vs execution token split
- Backtrack rate (file re-reads / total turns)
- RTMX tool token attribution (how many tokens does RTMX context add?)

**Statistical rigor**: Mann-Whitney U test for significance, bootstrap
confidence intervals on the efficiency ratio. Minimum N=5 runs per condition.

### Knowledge Entropy

rtmx-bench also introduces a **knowledge entropy** metric: a composite score
measuring how disorganized a project's documentation is. Dimensions:

| Dimension | What it measures | Computable without LLM |
|-----------|-----------------|----------------------|
| Scatter | Intent-bearing files across directories | Yes |
| Staleness | Documentation age vs code activity | Yes |
| Navigability | File reads to answer canonical questions | Requires agent |
| Duplication | Redundant paragraphs across files | Yes |

The composite score (0-10) enables cross-project comparison and correlation
analysis: do higher-entropy projects benefit more from RTMX?

## Quick Start

```bash
# Install dependencies
make setup

# Run a specific experiment
./bench.sh run url-shortener --condition control --runs 5
./bench.sh run url-shortener --condition treatment --runs 5

# Analyze results
make analyze

# Generate charts
make charts

# Scan a project's knowledge entropy
make entropy REPO=/path/to/your/project
```

## Running All Experiments

```bash
# Run all experiments with default settings (N=5 per condition)
make run-all

# Custom model and run count
make run-all MODEL=claude-opus-4-20250514 RUNS=10
```

## Adding Your Own Experiment

1. Write a task prompt in `prompts/<name>.md`
   - Describe the task in plain English
   - Include a clear success criterion
   - Do NOT mention RTMX, RTM, MCP, or requirements traceability
2. Create an experiment config in `experiments/<name>.yaml`
   - Specify `repo`, `test_command`, and optional `setup_command`
3. Build a treatment fixture in `fixtures/<name>/`
   - `rtm.csv`: RTMX database covering the task
   - `requirements/`: requirement specification files
4. Validate: `./bench.sh validate <name>`
5. Run: `./bench.sh run <name> --condition control --runs 5`

No harness code changes needed.

## Project Structure

```
rtmx-bench/
  bench.sh              -- experiment runner
  lib/                   -- shell library (CSV, tokens, verification)
  entropy/               -- knowledge entropy scanner
  analysis/              -- statistical analysis and visualization
  prompts/               -- task prompts (identical for both conditions)
  experiments/           -- experiment configuration files
  fixtures/              -- pre-built RTMX databases (treatment only)
  results/
    summary.csv          -- append-only data ledger (23 columns)
    charts/              -- generated visualizations
    raw/                 -- session transcripts (gitignored)
  tests/                 -- harness and entropy tests
  docs/                  -- schema and methodology documentation
```

## Requirements

- bash 4+
- git
- python3 with scipy, pandas, matplotlib
- Claude Code CLI (for running experiments)
- RTMX CLI (optional, for treatment condition seeding)

## Data Format

Results are stored in `results/summary.csv` with 24 columns. See
[docs/ledger-schema.md](docs/ledger-schema.md) for the complete schema.

## License

Apache 2.0
