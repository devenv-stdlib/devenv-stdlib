# CI and tests

[BATS](https://bats-core.readthedocs.io/) tests live in `tests/`:

```bash
bats -r --jobs "$(nproc)" tests   # full suite (parallel; needs GNU parallel)
bats tests/setup                  # setup.sh only
bats tests/home                   # terminal-lib, bashrc.d, Cursor LLM merge
```

`test-devenv-unit` runs nix-unit (with `--quiet`: hide ✅ lines, keep failures + summary) and BATS with `--jobs "$(nproc)"` (GNU `parallel` is on the devenv PATH). BATS TAP goes to `junit/bats.log`; the CI log gets a pass count, or the full log on failure.
`test-devenv-integration` runs nixosTest, actionlint, and nested act. Integration `nix-build` uses `-j "$(nproc)"`. Act step output is captured per job and printed only on failure.
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

CI installs the devenv CLI from the **locked** `devenv` input revision in `devenv.lock` (`github:cachix/devenv/<rev>`), not floating `nixpkgs#devenv`. That keeps the CLI aligned with `require_version: true` in `devenv.yaml`.

Host policy is the **current Ubuntu LTS and the previous one** (`modules/languages/versions-lib.nix` `ubuntuLts`: 26.04 and 24.04). Language jobs and `test-devenv-unit` / `test-devenv` / `setup-tests.yml` expand across those runners. `pages.yml`, `hooks.yml`, `update-lock.yml`, and `semantic-release` stay on `ubuntu-24.04`. Local `act` maps both labels to `devenv-act:24.04` and uses **rootless Docker** (`DOCKER_HOST`). Act mounts a Docker volume at `/nix`; the “Own workspace under act” step (and integration `test-devenv` before `act`) chowns it to the runner user so `install-nix-action` can do a single-user install. `test-devenv-integration` runs each act job with `-j` (one matrix cell at a time; `--concurrent-jobs 1` alone still overlapped cells on the shared volume and hit ENOSPC), and passes `TMPDIR` / `RUNNER_TEMP` because `install-nix-action` expands `RUNNER_TEMP` under `set -u`. GitHub-hosted runners keep the rootful daemon (`CI` / `GITHUB_ACTIONS` skip the helper). `.github/actionlint.yaml` lists `ubuntu-26.04` so actionlint 1.7.12 accepts the GitHub-hosted image.

Host jobs restore `/nix` from the GitHub Actions cache (`cache-nix-action/restore`), then **always save** after the job (`cache-nix-action/save` with `if: always()`) so a failed run still seeds the next restore. The combined action’s post step only runs on success, which left `test-devenv` with no cache keys. Act skips Actions cache (`!env.ACT`); nested jobs reuse the Docker `/nix` volume for that host run only. `cachix use devenv` stays pull-only (no push token).

`devenv shell` writes `.github/workflows/test.yml` as a reusable workflow (`workflow_call`) that runs `devenv test` per language per version. Cross-language matrices (Rust × Python) are not supported yet.

## JUnit

Unit and integration jobs write JUnit reports under `junit/` (gitignored). Logs stay summary-first: `junit-report.py --quiet` for nix-unit, BATS/act/nixosTest full transcripts on disk and on failure only in the job log. Tasks set `showOutput = true` (CI also passes `--show-output`) so those summaries are not swallowed. CI uploads the XML files and runs [publish-unit-test-result-action](https://github.com/EnricoMi/publish-unit-test-result-action).
