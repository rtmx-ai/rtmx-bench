# Contributing to rtmx-bench

Contributions of new experiments, analysis improvements, and bug fixes
are welcome.

## Adding a New Experiment

The most valuable contributions are new experiments that test the RTMX
efficiency hypothesis on different project types, languages, and task
complexities.

### Requirements

1. **Task prompt** (`prompts/<name>.md`): Describe the task in plain
   English. The prompt must NOT reference RTMX, RTM, MCP, requirements
   traceability, or any tool only available in the treatment condition.
   The agent discovers available tools from its environment.

2. **Experiment config** (`experiments/<name>.yaml`): Specify the
   repository to clone (or `none` for greenfield), the test command,
   and an optional setup command.

3. **Treatment fixture** (`fixtures/<name>/`): A pre-built RTMX database
   (`rtm.csv`) and optional requirement specs. The RTM should cover the
   same scope as the task prompt, with acceptance criteria, test mappings,
   and dependency ordering.

4. **Validation**: Run `./bench.sh validate <name>` and ensure it passes.
   The validator checks that the prompt has no RTMX references, the config
   loads, and the fixture RTM exists.

### Guidelines

- Keep prompts language-agnostic when possible (let the agent choose)
- Include a concrete success criterion that maps to test results
- For brownfield experiments, pin the repo to a specific commit SHA
- Pre-built RTMs should have 8-15 requirements (too few = trivial,
  too many = unrealistic for a single session)

## Submitting Results

If you run experiments and want to contribute your results:

1. Do NOT commit session transcripts (they may contain API keys)
2. Include your `results/summary.csv` rows with a note about your
   environment: model version, hardware, date
3. Results from different environments are disambiguated by the
   metadata columns in the ledger

## Development

```bash
# Run all tests
make test

# Validate all experiment configs
make validate

# Check entropy scanner on a repo
make entropy REPO=/path/to/repo
```

### Code Style

- Shell scripts: POSIX-compatible where possible, bash 4+ for arrays
- Python: stdlib first, minimize dependencies
- Tests: table-driven patterns, clear assertion messages
- No emojis in code or documentation

## License

By contributing, you agree that your contributions will be licensed
under the Apache 2.0 License.
