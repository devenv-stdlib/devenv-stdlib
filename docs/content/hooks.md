# Hooks and commits

Always-on hooks: Nix format/lint (`nixfmt`, `statix`, `deadnix`), `shellcheck`, `typos`, `proselint`, `lychee`, `actionlint`, `yamlfmt`, `check-json`, `check-toml`, `taplo` / `taplo-lint`, `trim-trailing-whitespace`, `end-of-file-fixer`, `check-added-large-files`, `check-case-conflicts`, `check-merge-conflicts` (Copier/git conflict markers), `gitleaks`, and `commitlint` on `commit-msg`.

## Language hooks

| `languages.*` | Hooks |
| --- | --- |
| `rust` | `rustfmt`, `clippy` |
| `go` | `gofmt`, `golangci-lint` |
| `python` | `ruff`, `ruff-format`, `check-python`, `python-debug-statements`, `sort-requirements-txt`, plus `pyright` or `ty` |
| `javascript` or `typescript` | `prettier` (JS/TS files only) |
| any of those | `debtmap` (reads generated `.debtmap.toml`) |

`devenv shell` writes `.debtmap.toml` (gitignored) from `languages.*` and `debtmap.*`. Override thresholds in `devenv.local.nix`; do not edit the generated file.

## Conventional Commits

Commit messages must follow [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, `ci:`, `test:`, `chore:`). The `commitlint` hook rejects other subjects. On push to `master` or `main`, CI runs [semantic-release](https://semantic-release.gitbook.io/semantic-release/) to version, tag, and publish a GitHub Release. Those tags are what `copier copy` and `copier update` use by default.

## CI

`hooks.yml` runs `prek run --all-files` on every pull request (after `devenv shell` writes the generated hook config). If prek fails, the job comments with the log (and uploads `prek.log`). A later green run removes that comment.

Autofixes (including PRs from forks) are pushed by [pre-commit.ci lite](https://pre-commit.ci/lite.html), not by `GITHUB_TOKEN`. Install the [pre-commit-ci-lite](https://github.com/apps/pre-commit-ci-lite) GitHub App on the repository. The Action job only has `contents: read`; the App applies the diff from outside the runner, which is how [pre-commit.ci](https://pre-commit.ci/) can write a fork branch. A fork `pull_request` workflow cannot do that itself: GitHub issues a read-only token and withholds repository secrets.

## Hook versions

Hooks do not use `pre-commit` `rev:` pins. `.pre-commit-config.yaml` is generated and gitignored; tool versions come from `devenv.lock` (`nixpkgs` and `git-hooks`). `pre-commit autoupdate` / full pre-commit.ci weekly updates do not apply.

Refresh the hook framework locally with `devenv update git-hooks`. `update-lock.yml` runs that weekly (and on `workflow_dispatch`) and opens `chore: refresh the git-hooks lock`. It does **not** run a full `devenv update`, so the `nixpkgs` and `devenv` pins stay put.

Hook binaries that come from this project's nixpkgs (`nixfmt`, `lychee`, `ruff`, …) move only when you intentionally `devenv update nixpkgs`. `debtmap` is a separate non-Nix catalog pin (mise or Nix promotion).

## Tag guard

Git has no `pre-tag` hook. `hooks/reference-transaction` runs the test suite when a tag is created or force-moved. `enterShell` installs it into `.git/hooks/`. `DEVENV_SKIP_TAG_TESTS=1 git tag ...` bypasses the check. The hook is a no-op when `CI` or `GITHUB_ACTIONS` is set so semantic-release can tag from GitHub Actions.
