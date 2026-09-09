# CI and tests

[BATS](https://bats-core.readthedocs.io/) tests live in `tests/`:

```bash
bats -r --jobs "$(nproc)" tests   # full suite (parallel; needs GNU parallel)
bats tests/setup                  # setup.sh only
bats tests/home                   # terminal-lib, bashrc.d, Cursor LLM merge
```

`test-devenv` runs BATS with `--jobs "$(nproc)"` (GNU `parallel` is on the devenv PATH).
nix-unit stays single-process (no `--jobs`; forking per topic file is slower than one suite).
Integration `nix-build` uses `-j "$(nproc)"` so dependency builds can run in parallel.
`tests/copier.bats` copies this template into a throwaway directory and checks `copier update`; it is excluded from generated monorepos.

## Workflows

| Workflow | Trigger | Runs |
| --- | --- | --- |
| `ci.yml` | Push and pull request to `main`/`master` | `test-devenv` on Ubuntu 24.04 and 26.04; then `test.yml` if it exists; `semantic-release` on push to `master`/`main`. Concurrent runs for the same PR/ref cancel in progress. |
| `test.yml` | Called from `ci.yml` | Per-language `devenv test` for each supported version, on Ubuntu 24.04 and 26.04 |
| `setup-tests.yml` | Changes to setup/tag hooks, and every tag push | `bats tests/setup tests/tag-hook.bats` on Ubuntu 24.04 and 26.04 |
| `pages.yml` | Push to `master`/`main`, pull request, or manual | Build the docs site; deploy to [devenv4monorepo.github.io](https://devenv4monorepo.github.io/) on `master`/`main` |
| `hooks.yml` | Pull request | `prek run --all-files`; comment with the log on failure; [pre-commit.ci lite](https://pre-commit.ci/lite.html) pushes autofixes (including forks) |
| `update-lock.yml` | Weekly Monday and `workflow_dispatch` | `devenv update git-hooks` only; PR when that input changes |

Host policy is the **current Ubuntu LTS and the previous one** (`modules/languages/versions-lib.nix` `ubuntuLts`: 26.04 and 24.04). Language jobs and `test-devenv` / `setup-tests.yml` expand across those runners. `pages.yml`, `hooks.yml`, `update-lock.yml`, and `semantic-release` stay on `ubuntu-24.04`. Local `act` maps both labels to `devenv-act:24.04` and uses **rootless Docker** (`DOCKER_HOST`). GitHub-hosted runners keep the rootful daemon (`CI` / `GITHUB_ACTIONS` skip the helper). `.github/actionlint.yaml` lists `ubuntu-26.04` so actionlint 1.7.12 accepts the GitHub-hosted image.

`devenv shell` writes `.github/workflows/test.yml` as a reusable workflow (`workflow_call`) that runs `devenv test` per language per version. Cross-language matrices (Rust × Python) are not supported yet.

## JUnit

`test-devenv` writes JUnit reports under `junit/` (gitignored). The runner streams original output to the log: `junit-report.py` tees nix-unit, BATS uses TAP (or `tee` on the JUnit fallback), and the `devenv:test-devenv` task sets `showOutput = true` (CI also passes `--show-output`) so devenv tasks do not swallow that stream. CI uploads those files and runs [publish-unit-test-result-action](https://github.com/EnricoMi/publish-unit-test-result-action).
