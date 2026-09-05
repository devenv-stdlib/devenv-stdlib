# Contribution guide

This page is for people changing **this template**. To apply it to a monorepo, see [Apply](#apply) and [Bootstrap](#bootstrap).

Clone this repository only to develop the template. Generated monorepos get a copy via Copier; they do not need this git history.

## Prerequisites

- Ubuntu 22.04 LTS (x86_64 or aarch64)
- `curl` and a user that can create `/nix`
- Host [prek](https://prek.j178.dev/), nixfmt, statix, and deadnix (Homebrew on the host). Commit on the host, not inside Docker — VMware user namespaces make `bwrap` flaky.

Languages stay **off** in this repo. Do not enable `languages.javascript` or `languages.typescript` to work on `docs/`; Node comes from `pkgs.nodejs` in `modules/packages.nix`. `devenv.local.nix` is gitignored here so a local experiment cannot leak into the template.

## First-time setup

```bash
./setup.sh
devenv shell
```

`setup.sh` installs Nix, devenv, Cachix (`cachix use devenv`), and Home Manager, then applies `home.nix`. After Alacritty, log out and back in once so GNOME Shell loads Quake Terminal.

`home-switch` re-applies Home Manager after you edit `home.nix` or `home.local.nix`.

## Daily loop

```bash
devenv shell                 # or direnv allow once
# edit modules/, home/, copier.yml, docs/content/, …
devenv test                  # enterTest + BATS
test-devenv                  # nix-unit, BATS, nixosTest, actionlint, act
```

`direnv allow` uses the committed `.envrc`. Alternatively `eval "$(devenv hook bash)"` plus `devenv allow`.

Do not edit `.devenv/` or other generated files. User-facing Nix is `devenv.nix`, `devenv.yaml`, `home.nix`, `modules/`, and `home/`.

## Generated files

| File | Writer | Git |
| --- | --- | --- |
| `.github/workflows/test.yml` | `modules/language-versions.nix` | committed |
| `.vscode/extensions.json` | `modules/cursor-languages.nix` | gitignored |
| `.vscode/settings.json` | `cursor-sync-extensions` | committed when it changes |
| `.debtmap.toml` | `modules/debtmap.nix` | gitignored |
| `.pre-commit-config.yaml` | git-hooks.nix / prek | gitignored |

## Documentation site

Published at [devenv4monorepo.github.io](https://devenv4monorepo.github.io/). The app lives in `docs/` (Vite, React, Spectrum web components, markdown via `?raw`). Copier does **not** copy `docs/` or `.github/workflows/pages.yml`.

```bash
docs-dev                     # http://localhost:5173
docs-build                   # docs/dist
```

Edit `docs/content/*.md`. New top-level topics: add the file, import it in `docs/src/sections.ts`. Sidenav headings are the `##` lines. `pages.yml` builds with `VITE_BASE=/` for the GitHub Pages hostname.

The README is marketing. Do not mirror these pages into `README.md`.

## Toolchain catalog

```bash
refresh-toolchain-latest
```

Fetches [endoflife.date](https://endoflife.date) into `modules/toolchain-catalog.json` and Copier max defaults (`includes/toolchain-latest.yml`). `includes/` is template-only (`_exclude`). The catalog JSON **does** ship with generated monorepos.

## Tests

```bash
bats -r tests
bats tests/setup
bats tests/home
bats tests/copier.bats
test-devenv                  # also writes junit/*.xml
build-act-image              # devenv-act:22.04 for local act
```

| Suite | Role |
| --- | --- |
| `tests/unit/` | nix-unit (versions, hooks, debtmap, Cursor, terminal, …) |
| `tests/setup/setup.bats` | `setup.sh` (sources the script; `main` guard) |
| `tests/copier.bats` | `copier copy` / `update`; not copied into monorepos |
| `tests/toolchain-latest.bats` | catalog alignment, no network |
| `tests/home/terminal-lib.bats` | eval `home/terminal-lib.nix` |
| `tests/tag-hook.bats` | failing suite blocks `git tag` |
| `tests/integration/` | nixosTest on Ubuntu 22.04 |

`test-devenv` `actionlint`s generated `test.yml` and fixtures, then `act workflow_call` on the Python fixture. Skip nested act when `ACT` is set. `.actrc` maps `ubuntu-22.04` to `devenv-act:22.04`.

## Commits and tags

One topic per commit. Subjects must pass `commitlint` (`@commitlint/config-conventional`) so semantic-release can version from `master`/`main`.

```
<type>: <imperative summary>
```

Types: `feat`, `fix`, `docs`, `ci`, `test`, `chore`. Breaking changes use a `BREAKING CHANGE:` footer.

`prek` runs `pre-commit` and `commit-msg`. `hooks/reference-transaction` (installed on `enterShell`) runs the suite when a tag is created or force-moved. `DEVENV_SKIP_TAG_TESTS=1 git tag …` bypasses it. The hook is a no-op when `CI` or `GITHUB_ACTIONS` is set.

## Copier exclusions

`copier.yml` `_exclude` replaces Copier’s defaults. Keep generated noise **and** template-only paths: `includes`, `docs`, `tests/copier.bats`, `.github/workflows/pages.yml`. If you add another template-only path, exclude it and assert that in `tests/copier.bats`.

`_skip_if_exists` leaves a destination `README.md` alone. Questionnaire output is `devenv.local.nix`, not a Jinja `devenv.nix`.

## Repository layout

| Path | Role |
| --- | --- |
| `setup.sh` | Host bootstrap (Nix, devenv, Cachix, Home Manager) |
| `copier.yml` | Questions and `_exclude` (not copied) |
| `devenv.local.nix.jinja` | Renders consumer `devenv.local.nix` |
| `includes/` | Catalog refresh script and Copier max YAML (not copied) |
| `modules/toolchain-catalog.json` | Cycle → latest patch and EOL (copied) |
| `docs/` | Pages site (not copied) |
| `devenv.nix` / `devenv.yaml` / `devenv.lock` | Shell, inputs, lock |
| `home.nix` / `home/` | Home Manager |
| `modules/` | Packages, languages, versions, hooks, debtmap, tests |
| `hooks/reference-transaction` | Tag guard |
| `commitlint.config.mjs` / `.releaserc.json` | Commits and releases |
| `tests/` | nix-unit, BATS, nixosTest, act image |
| `devenv.local.nix.example` / `home.local.nix.example` | Extra options |

## Local overrides

In **this** repo, `devenv.local.nix` and `home.local.nix` stay gitignored. Put host-only Home Manager lines in `home.local.nix`. Do not commit language enables here.

In a **generated** monorepo, commit `devenv.local.nix` and add extras below the Copier block (`devenv.local.nix.example`).
