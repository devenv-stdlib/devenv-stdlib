# CI and tests

[BATS](https://bats-core.readthedocs.io/) tests live in `tests/`:

```bash
bats -r tests           # full suite
bats tests/setup        # setup.sh only
bats tests/home         # terminal-lib.nix only
```

`tests/copier.bats` copies this template into a throwaway directory and checks `copier update`; it is excluded from generated monorepos.

## Workflows

| Workflow | Trigger | Runs |
| --- | --- | --- |
| `ci.yml` | Push and pull request to `main`/`master` | `test-devenv`; then `test.yml` if it exists; `semantic-release` on push to `master`/`main` |
| `test.yml` | Called from `ci.yml` | Per-language `devenv test` for each supported version (Ubuntu 22.04) |
| `setup-tests.yml` | Changes to setup/tag hooks, and every tag push | `bats tests/setup tests/tag-hook.bats` |
| `pages.yml` | Push to `master`/`main`, pull request, or manual | Build the docs site; deploy to [devenv4monorepo.github.io](https://devenv4monorepo.github.io/) on `master`/`main` |
| `hooks.yml` | Pull request | `prek run --all-files`; comment with the log on failure; [pre-commit.ci lite](https://pre-commit.ci/lite.html) pushes autofixes (including forks) |
| `update-lock.yml` | Weekly Monday and `workflow_dispatch` | `devenv update git-hooks` only; PR when that input changes |

`devenv shell` writes `.github/workflows/test.yml` as a reusable workflow (`workflow_call`) that runs `devenv test` per language per version. Cross-language matrices (Rust × Python) are not supported yet.

## JUnit

`test-devenv` writes JUnit reports under `junit/` (gitignored). CI uploads those files and runs [publish-unit-test-result-action](https://github.com/EnricoMi/publish-unit-test-result-action).
