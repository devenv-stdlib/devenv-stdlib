# CI and tests

[BATS](https://bats-core.readthedocs.io/) tests live in `tests/`:

```bash
bats -r --jobs 1 tests   # full suite (serial; git 2.55 + Nix fetcher races)
bats tests/setup                  # setup.sh only
bats tests/home                   # terminal-lib, bashrc.d, Cursor LLM merge, Serena config
```

`test-devenv-unit` runs nix-unit (with `--quiet`: hide ✅ lines, keep failures + summary) and BATS with `--jobs "$(nproc)"` (GNU `parallel` is on the devenv PATH). BATS TAP goes to `junit/bats.log`; the CI log gets a pass count, or the full log on failure.
`test-devenv-integration` runs nixosTest and actionlint. On GitHub-hosted runners (`GITHUB_ACTIONS`), nested act is skipped — the language matrix already runs via reusable `test.yml`. Locally, integration still runs nested act (matrix cells pinned one-at-a-time). Integration `nix-build` uses `-j "$(nproc)"`. Act step output is captured per job and printed only on failure.
Local `test-devenv` runs the unit suite, then the integration suite (skips integration if unit failed).
nix-unit stays single-process (no `--jobs`; forking per topic file is slower than one suite).
`tests/copier.bats` copies this template into a throwaway directory and checks `copier update`; it is excluded from generated monorepos.

## Workflows

| Workflow | Trigger | Runs |
| --- | --- | --- |
| `ci.yml` | Push and pull request to `main`/`master` | `test-devenv-unit` on Ubuntu 24.04 and 26.04; then `test-devenv` (integration) on the same OS matrix after every unit cell succeeds; then `test.yml` if it exists; `semantic-release` on push to `master`/`main`. Concurrent runs for the same PR/ref cancel in progress. |
| `test.yml` | Called from `ci.yml` | Per-language `devenv test` for each supported version, on Ubuntu 24.04 and 26.04 |
| `setup-tests.yml` | Changes to setup/tag hooks, and every tag push | `bats tests/setup tests/tag-hook.bats` on Ubuntu 24.04 and 26.04 |
| `pages.yml` | Push to `master`/`main`, pull request, or manual | Build the docs site; deploy to [devenv4monorepo.github.io](https://devenv4monorepo.github.io/) on `master`/`main` |
| `hooks.yml` | Pull request | `prek run --all-files`; comment with the log on failure; [pre-commit.ci lite](https://pre-commit.ci/lite.html) pushes autofixes (including forks) |
| `update-lock.yml` | Weekly Monday and `workflow_dispatch` | `devenv update git-hooks` only; PR when that input changes |

CI and `setup.sh` install the devenv CLI from the **locked** `devenv` input revision in `devenv.lock` (`github:cachix/devenv/<rev>`), not floating `nixpkgs#devenv`. That keeps the CLI aligned with `require_version: true` in `devenv.yaml`. The v2.4.0 modules tag still ships `latest-version=2.3.1`, so `devenv.nix` sets `devenv.latestVersion = "2.4.0"` to match the release CLI.

Host policy is the **current Ubuntu LTS and the previous one** (`modules/languages/versions-lib.nix` `ubuntuLts`: 26.04 and 24.04). Language jobs and `test-devenv-unit` / `test-devenv` / `setup-tests.yml` expand across those runners. `pages.yml`, `hooks.yml`, `update-lock.yml`, and `semantic-release` stay on `ubuntu-24.04`. Local `act` maps both labels to `devenv-act:24.04` and uses **rootless Docker** (`DOCKER_HOST`). Act mounts a Docker volume at `/nix`; the “Own workspace under act” step chowns it to the runner user so `install-nix-action` can do a single-user install. Local `test-devenv-integration` runs each act job with `-j` (one matrix cell at a time; `--concurrent-jobs 1` alone still overlapped cells on the shared volume and hit ENOSPC), and passes `TMPDIR` / `RUNNER_TEMP` because `install-nix-action` expands `RUNNER_TEMP` under `set -u`. GitHub-hosted runners skip nested act entirely (`GITHUB_ACTIONS`) and keep the rootful daemon for any other Docker use. `.github/actionlint.yaml` lists `ubuntu-26.04` so actionlint 1.7.12 accepts the GitHub-hosted image.

Host jobs restore `/nix` from the GitHub Actions cache (`cache-nix-action/restore`), then **always save** after the job (`cache-nix-action/save` with `if: always()`) so a failed run still seeds the next restore. The combined action’s post step only runs on success, which left `test-devenv` with no cache keys. Act skips Actions cache (`!env.ACT`); nested jobs reuse the Docker `/nix` volume for that host run only. `cachix use devenv` stays pull-only (no push token).

`devenv shell` writes `.github/workflows/test.yml` as a reusable workflow (`workflow_call`) that runs `devenv test` per language per version. That writer is the composable preset `ci.language-matrix` (`presets/ci/language-matrix.nix`), not a megapreset named “CI”. Cross-language matrices (Rust × Python) are not supported yet. The stdlib status report (eval warnings + `enterShell`) lists the resulting matrix alongside enabled git-hooks.

## JUnit

Unit and integration jobs write JUnit reports under `junit/` (gitignored). Logs stay summary-first: `junit-report.py --quiet` for nix-unit, BATS/act/nixosTest full transcripts on disk and on failure only in the job log. Tasks set `showOutput = true` (CI also passes `--show-output`) so those summaries are not swallowed. CI uploads the XML files and runs [publish-unit-test-result-action](https://github.com/EnricoMi/publish-unit-test-result-action).
