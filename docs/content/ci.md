# CI and tests

[BATS](https://bats-core.readthedocs.io/) tests live in `tests/`:

```bash
bats -r --jobs "$(nproc)" tests   # full suite (parallel; needs GNU parallel)
bats tests/setup                  # setup.sh only
bats tests/home                   # terminal-lib, bashrc.d, Cursor LLM merge, Serena config
```

`test-devenv` runs BATS with `--jobs "$(nproc)"` (GNU `parallel` is on the devenv PATH).
nix-unit stays single-process (no `--jobs`; forking per topic file is slower than one suite).
Integration `nix-build` uses `-j 1` under `CI` / `GITHUB_ACTIONS` (serial; shared runner disk); locally it still uses `-j "$(nproc)"`.
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

CI and `setup.sh` install the devenv CLI from the **locked** `devenv` input revision in `devenv.lock` (`github:cachix/devenv/<rev>`), not floating `nixpkgs#devenv`. That keeps the CLI aligned with `require_version: true` in `devenv.yaml`. The v2.4.0 modules tag still ships `latest-version=2.3.1`, so `devenv.nix` sets `devenv.latestVersion = "2.4.0"` to match the release CLI.

Host policy is the **current Ubuntu LTS and the previous one** (`modules/languages/versions-lib.nix` `ubuntuLts`: 26.04 and 24.04). Language jobs and `test-devenv` / `setup-tests.yml` expand across those runners. `pages.yml`, `hooks.yml`, `update-lock.yml`, and `semantic-release` stay on `ubuntu-24.04`. Local `act` maps both labels to `devenv-act:24.04` and uses **rootless Docker** (`DOCKER_HOST`). Act mounts a Docker volume at `/nix`; the “Own workspace under act” step (and `test-devenv` before `act`) chowns it to the runner user so `install-nix-action` can do a single-user install. `test-devenv` runs each act job with `-j` (one matrix cell at a time; `--concurrent-jobs 1` alone still overlapped cells on the shared volume and hit ENOSPC), and passes `TMPDIR` / `RUNNER_TEMP` because `install-nix-action` expands `RUNNER_TEMP` under `set -u`. GitHub-hosted runners keep the rootful daemon (`CI` / `GITHUB_ACTIONS` skip the helper). `.github/actionlint.yaml` lists `ubuntu-26.04` so actionlint 1.7.12 accepts the GitHub-hosted image.

Host jobs restore `/nix` from the GitHub Actions cache (`cache-nix-action/restore`), then **always save** after the job (`cache-nix-action/save` with `if: always()`) so a failed run still seeds the next restore. The combined action’s post step only runs on success, which left `test-devenv` with no cache keys. Act skips Actions cache (`!env.ACT`); nested jobs reuse the Docker `/nix` volume for that host run only. `cachix use devenv` stays pull-only (no push token).

`devenv shell` writes `.github/workflows/test.yml` as a reusable workflow (`workflow_call`) that runs `devenv test` per language per version. Cross-language matrices (Rust × Python) are not supported yet.

## JUnit

`test-devenv` writes JUnit reports under `junit/` (gitignored). The runner streams original output to the log: `junit-report.py` tees nix-unit, BATS uses TAP (or `tee` on the JUnit fallback), and the `devenv:test-devenv` task sets `showOutput = true` (CI also passes `--show-output`) so devenv tasks do not swallow that stream. CI uploads those files and runs [publish-unit-test-result-action](https://github.com/EnricoMi/publish-unit-test-result-action).
