# CI and tests

[BATS](https://bats-core.readthedocs.io/) tests live in `tests/`:

```bash
bats -r --jobs 1 tests   # full suite (serial; git 2.55 + Nix fetcher races)
bats tests/setup                  # setup.sh only
bats tests/home                   # terminal-lib, bashrc.d, Cursor LLM merge, Serena config
```

`test-devenv-unit` runs nix-unit (with `--quiet`: hide ✅ lines, keep failures + summary) and BATS with `--jobs "$(nproc)"` (GNU `parallel` is on the devenv PATH). BATS TAP goes to `junit/bats.log`; the CI log gets a pass count, or the full log on failure.

nix-unit is **not** one megasuite: the main suite covers stdlib, Den aspects, and other cross-cutting topics under `tests/unit/`, then the runner discovers each `tools/**/tests/unit/default.nix` and `presets/**/tests/unit/default.nix` and runs them as separate suites (JUnit files `nix-unit.xml` plus `nix-unit-<slug>.xml`). See [contributing](contributing.md#test-layout).

`test-devenv-integration` runs the main nixosTest and actionlint, then builds any discovered `tools|presets/**/tests/integration/default.nix`. On GitHub-hosted runners (`GITHUB_ACTIONS`), nested act is skipped — the language matrix already runs via reusable `test.yml`. Locally, integration still runs nested act (matrix cells pinned one-at-a-time). Integration `nix-build` uses `-j "$(nproc)"`. Act step output is captured per job and printed only on failure.
Local `test-devenv` runs the unit suite, then the integration suite (skips integration if unit failed).
Each nix-unit suite stays single-process (no `--jobs`).
`tests/copier.bats` copies this template into a throwaway directory and checks `copier update`; it is excluded from generated monorepos.

## Workflows

| Workflow | Trigger | Runs |
| --- | --- | --- |
| `ci.yml` | Push and pull request to `main`/`master` | **Lint (prek)** always first (fail-fast; treefmt + residual prek). On PRs, **Detect path changes** skips unit / integration / language-matrix when their paths are untouched; push to `main`/`master` always runs the full suite. Ruleset check names stay green on intentional path-skips via shim jobs. |
| `test.yml` | Called from `ci.yml` | Per-language `devenv test` for each supported version, on Ubuntu 24.04 and 26.04 (human-readable job titles per language/version) |
| `setup-tests.yml` | Changes to setup/tag hooks, every tag push, and every PR | **setup.sh BATS** when setup paths change (PR path-filter + push `paths:`; ruleset shim `bats (ubuntu-…)` stays green on skip) |
| `pages.yml` | Push to `master`/`main`, pull request, or manual | **Build docs site** when `docs/**` (or this workflow) changes on PRs; always on trunk push / `workflow_dispatch` for deploy (ruleset shim `build`) |
| `update-lock.yml` | Weekly Monday and `workflow_dispatch` | `devenv update git-hooks` only; PR when that input changes |

CI and `setup.sh` install the devenv CLI from the **locked** `devenv` input revision in `devenv.lock` (`github:cachix/devenv/<rev>`), not floating `nixpkgs#devenv`. That keeps the CLI aligned with `require_version: true` in `devenv.yaml`. The v2.4.0 modules tag still ships `latest-version=2.3.1`, so `devenv.nix` sets `devenv.latestVersion = "2.4.0"` to match the release CLI.

Host policy is the **current Ubuntu LTS and the previous one** (`modules/languages/versions-lib.nix` `ubuntuLts`: 26.04 and 24.04). Language jobs and unit / integration / `setup-tests.yml` expand across those runners when their path filters match. Lint (`prek`), path-detect jobs, docs build, `update-lock.yml`, and semantic-release stay on `ubuntu-24.04`. Local `act` maps both labels to `devenv-act:24.04` and uses **rootless Docker** (`DOCKER_HOST`). Act mounts a Docker volume at `/nix`; the “Own workspace under act” step chowns it to the runner user so `install-nix-action` can do a single-user install. Local `test-devenv-integration` runs each act job with `-j` (one matrix cell at a time; `--concurrent-jobs 1` alone still overlapped cells on the shared volume and hit ENOSPC), and passes `TMPDIR` / `RUNNER_TEMP` because `install-nix-action` expands `RUNNER_TEMP` under `set -u`. GitHub-hosted runners skip nested act entirely (`GITHUB_ACTIONS`) and keep the rootful daemon for any other Docker use. `.github/actionlint.yaml` lists `ubuntu-26.04` so actionlint 1.7.12 accepts the GitHub-hosted image.

Host jobs restore `/nix` from the GitHub Actions cache (`cache-nix-action/restore`), then **always save** after the job (`cache-nix-action/save` with `if: always()`) so a failed run still seeds the next restore. The combined action’s post step only runs on success, which left `test-devenv` with no cache keys. Act skips Actions cache (`!env.ACT`); nested jobs reuse the Docker `/nix` volume for that host run only. `cachix use devenv` stays pull-only (no push token).

`devenv shell` writes `.github/workflows/test.yml` as a reusable workflow (`workflow_call`) that runs `devenv test` per language per version. That writer is the composable preset `ci.github_actions.language-matrix` (`presets/ci/github_actions/language-matrix.nix`). Cross-language matrices (Rust × Python) are not supported yet. The stdlib status report (eval warnings + `enterShell`) lists the resulting matrix alongside enabled git-hooks.

## JUnit

Unit and integration jobs write JUnit reports under `junit/` (gitignored). Logs stay summary-first: `junit-report.py --quiet` for nix-unit, BATS/act/nixosTest full transcripts on disk and on failure only in the job log. Tasks set `showOutput = true` (CI also passes `--show-output`) so those summaries are not swallowed. CI uploads the XML files and runs [publish-unit-test-result-action](https://github.com/EnricoMi/publish-unit-test-result-action).
