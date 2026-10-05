# Hooks, linters, and commits

Linting is first-class under `linters.*` (parallel to `languages.*`). Most formatters and file linters run through [devenv’s treefmt integration](https://devenv.sh/integrations/treefmt/) (`treefmt-nix`). Residual checks that are a poor fit for treefmt stay on [prek](https://prek.j178.dev/) / git-hooks.

## Split: treefmt vs prek

| Backend        | Always-on (defaults)                                                                                                                                                                                         | Role                                                                                             |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------ |
| **treefmt**    | `nixfmt`, `statix`, `deadnix`, `shellcheck`, `yamlfmt`, `typos`, `actionlint`, `taplo`                                                                                                                       | Format / lint files via one `treefmt` config and one git-hooks entry (`treefmt`)                 |
| **prek**       | `commitlint`, `gitleaks`, `proselint`, `check-json`, `check-toml`, `taplo-lint`, `trim-trailing-whitespace`, `end-of-file-fixer`, `check-added-large-files`, `check-case-conflicts`, `check-merge-conflicts` | Commit-msg, secrets, prose, JSON/TOML syntax, hygiene                                            |
| **prek (off)** | `lychee`                                                                                                                                                                                                     | Link checker — keep `lychee.toml` / retry wrapper; set `linters.lychee.enable = true` to turn on |

Toggle any of them with `linters.<name>.enable` in `devenv.local.nix` (or `devenv.nix`). Catalog and backends live in `stdlib/linters.nix`; wiring is `modules/linters` (treefmt) + `modules/hooks/common.nix` (prek residual).

## Language formatters

Language-gated formatters are still thin tool presets (`presets/<lang>/lint/…` → `tools/lang/…/linters/`). When applied they enable **treefmt programs** (not separate git-hooks entries):

| `languages.*`                | Treefmt programs              | Still on prek                                                                        |
| ---------------------------- | ----------------------------- | ------------------------------------------------------------------------------------ |
| `rust`                       | `rustfmt`                     | `clippy`                                                                             |
| `go`                         | `gofmt`                       | `golangci-lint`                                                                      |
| `python`                     | `ruff-check`, `ruff-format`   | `check-python`, `python-debug-statements`, `sort-requirements-txt`, `pyright` / `ty` |
| `javascript` or `typescript` | `prettier` (JS/TS globs only) | —                                                                                    |
| any of those                 | —                             | `debtmap` (reads generated `.debtmap.toml`)                                          |

`devenv shell` writes `.debtmap.toml` (gitignored) from `languages.*` and `debtmap.*`. Override thresholds in `devenv.local.nix`; do not edit the generated file.

## Local and CI commands

```bash
# Format / lint every treefmt-backed program (writes fixes)
treefmt

# Check mode (fail if files would change; verbose formatter logs)
treefmt --ci --verbose

# Full hook set: treefmt + residual prek (commit-msg hooks need a commit)
prek run --all-files
```

The generated `treefmt` git-hooks / prek entry is check mode, not format-only:

```text
treefmt --ci --verbose
```

Pinned in `modules/linters` via `git-hooks.hooks.treefmt.args = [ "--ci" "--verbose" ]` (`settings.fail-on-change` / `no-cache` left false so those flags are not duplicated — `--ci` already enables both). So `prek run --all-files` in CI fails when any treefmt-backed program would rewrite a file, and logs show which formatter failed and why.

`ci.yml` runs **Lint (prek)** (`prek run --all-files`) before unit/integration/language-matrix jobs so formatting and static checks fail fast. That single prek run includes the `treefmt` hook plus residual checks. On pull requests, a failed run comments with the log (and uploads `prek.log`); a later green run removes that comment. The ruleset required check is the real job name **Lint (prek)**.

Autofixes (including PRs from forks) are pushed by [pre-commit.ci lite](https://pre-commit.ci/lite.html), not by `GITHUB_TOKEN`. Install the [pre-commit-ci-lite](https://github.com/apps/pre-commit-ci-lite) GitHub App on the repository. The Action job only has `contents: read`; the App applies the diff from outside the runner, which is how [pre-commit.ci](https://pre-commit.ci/) can write a fork branch. A fork `pull_request` workflow cannot do that itself: GitHub issues a read-only token and withholds repository secrets.

## Conventional Commits

Commit messages must follow [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, `ci:`, `test:`, `chore:`). The `commitlint` hook rejects other subjects. On push to `master` or `main`, CI runs [semantic-release](https://semantic-release.gitbook.io/semantic-release/) to version, tag, and publish a GitHub Release. Those tags are what `copier copy` and `copier update` use by default.

## Hook versions

Hooks do not use `pre-commit` `rev:` pins. `.pre-commit-config.yaml` is generated and gitignored; tool versions come from `devenv.lock` (`nixpkgs`, `git-hooks`, `treefmt-nix`). `pre-commit autoupdate` / full pre-commit.ci weekly updates do not apply.

Refresh the hook framework locally with `devenv update git-hooks`. `update-lock.yml` runs that weekly (and on `workflow_dispatch`) and opens `chore: refresh the git-hooks lock`. It does **not** run a full `devenv update`, so the `nixpkgs` and `devenv` pins stay put. Bump formatters with `devenv update treefmt-nix` or an intentional `devenv update nixpkgs`.

Hook binaries that come from this project's nixpkgs (`nixfmt`, `lychee`, `ruff`, …) move only when you intentionally `devenv update nixpkgs`. `debtmap` is a separate non-Nix catalog pin (mise or Nix promotion).

## Tag guard

Git has no `pre-tag` hook. `hooks/reference-transaction` runs the test suite when a tag is created or force-moved. `enterShell` installs it into `.git/hooks/`. `DEVENV_SKIP_TAG_TESTS=1 git tag ...` bypasses the check. The hook is a no-op when `CI` or `GITHUB_ACTIONS` is set so semantic-release can tag from GitHub Actions.
