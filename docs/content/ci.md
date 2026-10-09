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

## Workflows

| Workflow | Trigger | Runs |
| --- | --- | --- |
| `ci.yml` | Push and pull request to `main`/`master` | **Lint (prek)** always first (fail-fast; treefmt + residual prek). On PRs, **Detect path changes** skips unit / integration / language-matrix when their paths are untouched; push to `main`/`master` always runs the full suite. Path-skipped jobs report as skipped against the ruleset’s real job names. |
| `test.yml` | Called from `ci.yml` | Per-language `devenv test` for each supported version, on Ubuntu 24.04 and 26.04 (human-readable job titles per language/version) |
| `setup-tests.yml` | Changes to setup/tag hooks, every tag push, and every PR | **setup.sh BATS** when setup paths change (PR path-filter + push `paths:`; skipped when untouched) |
| `pages.yml` | Push to `master`/`main`, pull request, or manual | **Build docs site** when `docs/**` (or this workflow) changes on PRs; always on trunk push / `workflow_dispatch` for deploy |
| `pr-quality.yml` | `pull_request` (`opened` / `synchronize` / `reopened` / `ready_for_review`) | [peakoss/anti-slop](https://github.com/marketplace/actions/anti-slop) when `presets.ci.github_actions.anti-slop.enable` — **parallel** with **Lint (prek)** (own workflow; not `needs:`-gated). Job/check **`PR quality (anti-slop)`** fails on gate failure; add that context to the branch ruleset after merge to block merge. Drafts exempt by default. |
| `pr-metrics.yml` | Pull request (opened / sync / ready_for_review / …) | [microsoft/PR-Metrics](https://github.com/marketplace/actions/pr-metrics) when `presets.ci.github_actions.pr-metrics.enable` — **parallel** with **Lint (prek)** (own workflow). Job/check **`PR size (pr-metrics)`** fails when reject-above-medium trips; add that context to the branch ruleset after merge to block merge. Drafts skipped by default. |
| `update-lock.yml` | Weekly Monday and `workflow_dispatch` | `devenv update git-hooks` only; PR when that input changes |

CI and `setup.sh` install the devenv CLI from the **locked** `devenv` input revision in `devenv.lock` (`github:cachix/devenv/<rev>`), not floating `nixpkgs#devenv`. That keeps the CLI aligned with `require_version: true` in `devenv.yaml`. The v2.4.0 modules tag still ships `latest-version=2.3.1`, so `devenv.nix` sets `devenv.latestVersion = "2.4.0"` to match the release CLI.

Host policy is the **current Ubuntu LTS and the previous one** (`modules/languages/versions-lib.nix` `ubuntuLts`: 26.04 and 24.04). Language jobs and unit / integration / `setup-tests.yml` expand across those runners when their path filters match. Lint (`prek`), path-detect jobs, docs build, `update-lock.yml`, and semantic-release stay on `ubuntu-24.04`. Local `act` maps both labels to `devenv-act:24.04` and uses **rootless Docker** (`DOCKER_HOST`). Act mounts a Docker volume at `/nix`; the “Own workspace under act” step chowns it to the runner user so `install-nix-action` can do a single-user install. Local `test-devenv-integration` runs each act job with `-j` (one matrix cell at a time; `--concurrent-jobs 1` alone still overlapped cells on the shared volume and hit ENOSPC), and passes `TMPDIR` / `RUNNER_TEMP` because `install-nix-action` expands `RUNNER_TEMP` under `set -u`. GitHub-hosted runners skip nested act entirely (`GITHUB_ACTIONS`) and keep the rootful daemon for any other Docker use. `.github/actionlint.yaml` lists `ubuntu-26.04` so actionlint 1.7.12 accepts the GitHub-hosted image.

Host jobs restore `/nix` from the GitHub Actions cache (`cache-nix-action/restore`), then **always save** after the job (`cache-nix-action/save` with `if: always()`) so a failed run still seeds the next restore. The combined action’s post step only runs on success, which left `test-devenv` with no cache keys. Act skips Actions cache (`!env.ACT`); nested jobs reuse the Docker `/nix` volume for that host run only. `cachix use devenv` stays pull-only (no push token).

`ci.yml` and the generated `test.yml` set `MISE_GITHUB_TOKEN: ${{ github.token }}` at the workflow level. Every `devenv shell` and `devenv test` runs `mise install`, and `github:` tools such as debtmap call the GitHub API, which allows 60 unauthenticated requests per hour per runner IP. The built-in token needs no repository secret. The Lint job still clears `GITHUB_TOKEN` and `GH_TOKEN` for hooks, and its token is read-only (`contents: read`).

`devenv shell` does not write `.github/workflows/test.yml`. The stdlib status report dry-runs that file and names `devenv tasks run ci:update-language-matrix` (or `stdlib:update-generated`) when it is stale. The writer is the composable preset `ci.github_actions.language-matrix` (`presets/ci/github_actions/language-matrix.nix`).

The build matrix is declared as a provider-agnostic **MatrixPlan** (`stdlib.ci.matrix`): named dimensions, cartesian or explicit allow lists, `exclude` filters, `include` cells appended after exclusion, and abstract **runner profiles** with a `providers.github_actions` bag (`runs-on`, …). The GHA backend (`stdlib.ci.backends.github_actions.render`) turns a plan into `test.yml`. GitLab CI, CircleCI, and Bitbucket Pipelines are out of scope for this phase (tracked separately). Cross-language matrices (Rust × Python) are not supported yet. The stdlib status report (eval warnings + `enterShell`) lists the resulting matrix alongside enabled git-hooks.

`devenv shell` does **not** write `.github/workflows/pr-quality.yml` or `.github/workflows/pr-metrics.yml`. When you enable `ci.github_actions.anti-slop` or `ci.github_actions.pr-metrics`, the stdlib status report dry-runs those files and names `devenv tasks run ci:update-anti-slop` / `ci:update-pr-metrics` (or `stdlib:update-generated`) when they are stale.

The anti-slop workflow ([peakoss/anti-slop](https://github.com/peakoss/anti-slop)) runs on `pull_request` (`opened`, `synchronize`, `reopened`, `ready_for_review`) — a forge-side PR quality gate that runs **in parallel** with Lint (prek) in `ci.yml` (separate workflow; unit/integration still use lint as their fail-fast `needs:` gate). Failures fail the **`PR quality (anti-slop)`** check run (job `name:`, same style as Lint); require that context on the branch ruleset after merge to stop merge when the gate fails. `exemptDraftPrs` (default true) skips scanning drafts — keep ruleset “do not require on drafts” aligned, or set `exemptDraftPrs = false` for always-on. `ready_for_review` is required because anti-slop reads draft status from the Actions event payload only; re-runs keep a frozen draft-era payload, so draft→ready must start a new run. It intentionally uses `pull_request` (not `pull_request_target`) so the workflow file on the PR head is eligible to run (dogfood on the introducing PR and any tip that has not landed on the default branch; `pull_request_target` loads the workflow from the repository’s **default** branch, not the PR’s base). Tradeoff: for fork PRs GitHub often makes the `pull_request` token read-only, so `close-pr` may not close outsider PRs despite `pull-requests: write`. After `pr-quality.yml` is on the **default** branch, consumers who need privileged fork-close can change the committed workflow’s `on:` to `pull_request_target` with `types: [opened, synchronize, reopened, ready_for_review]` (keep the job API-only — no checkout of the PR head). On public repositories without an applicable Actions event policy that allows `pull_request_target`, GitHub’s default event policy will block those runs starting 2 November 2026 (private/internal repos are not covered); see [About Actions policies](https://docs.github.com/en/actions/concepts/about-actions-policies). It is not a treefmt or prek hook and cannot run locally.

**Consumers (opt-in):** marketplace Actions are off by default. Enable the same presets this template dogfoods:

```nix
presets.ci.github_actions.anti-slop.enable = true;
presets.ci.github_actions.pr-metrics.enable = true;
```

Then run `devenv tasks run ci:update-anti-slop` / `ci:update-pr-metrics` (or `stdlib:update-generated`) and commit the workflow files. For anti-slop, tune `action` (default pins the v0.3.0 commit SHA; `actionComment` labels the `uses:` line), `maxFailures`, `closePr` (false by default — scan without auto-close; set true for close-on-fail), `exemptDraftPrs` (drafts exempt by default), `exemptAuthorAssociation` (empty by default — no OWNER/MEMBER/COLLABORATOR skip; marketplace default would exempt those), `requireCommitAuthorMatch` (false by default; set true to ban non-author commits / LLM tips), `requireMaintainerCanModify` (false by default — marketplace check fails every same-repo PR because GitHub always reports `maintainer_can_modify: false` when head and base share a repo), or pass further Action inputs via `extraWith`. Disable with `enable = false` and remove the workflow file. See `presets/examples/ci-anti-slop.nix` and `presets/examples/ci-pr-metrics.nix`.

## JUnit

Unit and integration jobs write JUnit reports under `junit/` (gitignored). Logs stay summary-first: `junit-report.py --quiet` for nix-unit, BATS/act/nixosTest full transcripts on disk and on failure only in the job log. Tasks set `showOutput = true` (CI also passes `--show-output`) so those summaries are not swallowed. CI uploads the XML files and runs [publish-unit-test-result-action](https://github.com/EnricoMi/publish-unit-test-result-action).
