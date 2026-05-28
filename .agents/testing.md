# testing — test runner detection reference

How the review agent detects and runs this repo's test suite. Results
are embedded in the unified review artifact at `.reviews/<pr-number>/<sha>.md`
(see [`code-review.md`](./code-review.md)). The `/test-suite` skill follows the
same detection logic but reports to chat without writing an artifact.

## Detect the runner

Inspect the repo in this order; if multiple match, prefer the one CI runs
(see `.github/workflows/`):

| Project file | Likely runner | Command |
|---|---|---|
| `package.json` → `scripts.test` | `bun test`, `vitest`, `jest`, `mocha`, `node --test` | from the script |
| `pyproject.toml` / `setup.py` / `tox.ini` | `pytest`, `tox`, `unittest` | `pytest`, `tox`, `python -m unittest` |
| `Cargo.toml` | `cargo test` | `cargo test` |
| `go.mod` | `go test` | `go test ./...` |
| `Gemfile` | `rspec` / `rake test` | `bundle exec rspec` / `bundle exec rake test` |
| `mix.exs` | `mix test` | `mix test` |
| `.github/workflows/*.yml` | fall back | the test `run:` step |

## Install deps if missing

Only if the lock/manifest indicates deps aren't resolved (no `node_modules/`,
no `.venv/`, etc.). Use the project's standard step. Per global CLAUDE.md §5,
prefer `bun install` over `npm install` even when a `package-lock.json` exists.

## Run

Capture combined stdout+stderr, exit code, and wall-clock time. **One run per
invocation** — don't retry until green. Flaky tests are findings, not silent
retries. Don't run partial subsets when CI runs the full suite.

## Status rules (`test_status` frontmatter)

- `pass` — `exit_code == 0` AND `counts.failed == 0`
- `fail` — `counts.failed > 0`
- `partial` — some suites ran, some couldn't (e.g. compile error in one package)
- `error` — couldn't run at all (no runner, install failed). Use honestly;
  never pretend a non-run is a pass.

## What NOT to do

- Don't edit test files to make them pass — failing tests become findings.
- Don't mark `pass` when tests were skipped due to install failures (`error`).
- Don't re-run until green.
