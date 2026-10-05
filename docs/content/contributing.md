# Contribution guide

This page is for people changing **this template**. To apply it to a monorepo, see [Apply](#apply) and [Bootstrap](#bootstrap).

Clone this repository only to develop the template. Generated monorepos get a copy via Copier; they do not need this git history.

## Prerequisites

- Ubuntu 26.04 or 24.04 LTS (x86_64 or aarch64)
- `curl` and a user that can create `/nix`
- Host [prek](https://prek.j178.dev/), nixfmt, statix, and deadnix (Homebrew on the host). Commit on the host, not inside Docker — VMware user namespaces make `bwrap` flaky.

Languages stay **off** in this repo. Do not enable `languages.javascript` or `languages.typescript` to work on `docs/`; Node comes from `pkgs.nodejs` in `modules/packages/`. `devenv.local.nix` is gitignored here so a local experiment cannot leak into the template.

## First-time setup

```bash
./setup.sh
devenv shell
```

`setup.sh` installs Nix, devenv, Cachix (`cachix use devenv`), and Home Manager, then applies the Den developer profile. After Alacritty, log out and back in once so GNOME Shell loads Quake Terminal.

`home-switch` re-applies Home Manager after you edit Den aspects (`modules/aspects/`, `modules/den/`) or `home.local.nix`.

## Daily loop

```bash
devenv shell                 # or direnv allow once
# edit modules/, home/, copier.yml, docs/content/, …
devenv test                  # enterTest + BATS
test-devenv                  # unit then integration (nix-unit, BATS, nixosTest, actionlint, act)
test-devenv-unit             # nix-unit + BATS
test-devenv-integration      # nixosTest, actionlint, act
devenv update git-hooks      # refresh only the git-hooks lock input
```

`direnv allow` uses the committed `.envrc`. Alternatively `eval "$(devenv hook bash)"` plus `devenv allow`.

Do not edit `.devenv/` or other generated files. User-facing Nix is `devenv.nix`, `devenv.yaml`, `flake.nix`, `modules/`, and `home/`.

`modules/` is topical: devenv (`hooks/`, `languages/`, `ides/`, `debtmap/`, `packages/`, `update/`, `test/`, `lib/`) plus Den (`aspects/`, `den/`, discovered by flake `import-tree`). `home/ides/` holds editors and the MCP catalog. `modules/devenv.nix` is the devenv barrel (`devenv.yaml` imports it explicitly). Prefer small focused files over growing grab-bags; the Cursor rule `.cursor/rules/nix-module-split.mdc` (copied) requires a split when a module mixes concerns, grows past ~100 lines, or duplicates patterns in the same directory. Obvious cuts land in the same change; large ambiguous moves need a proposed tree first.

## Maintainer workflow

Clone this repo only to change the template. Bumping a shipped pin here is how the **next tag** (semantic-release) gives users a newer tool via `copier update`.

```bash
devenv shell
update                    # rewrite in-tree pins + hashes from GitHub/npm/PyPI/Docker
# review the diff, test, commit (feat/chore), push; do not mix with docs
devenv update git-hooks   # lock only; weekly CI already does this
# devenv update nixpkgs   # only when you intend to move nixpkgs-based hook binaries
refresh-toolchain-latest  # endoflife catalog; separate from update
```

`update` in this checkout does **not** run a full `devenv update`. Lock policy stays: `git-hooks` weekly; nixpkgs only when intended. Bump the `devenv` input (and matching `require_version` / CLI install pin) only when intentionally moving to a new devenv release.

When adding a non-Nix tool to the **template**: run `devenv tasks run non-nix:add -- …` (or edit `modules/non-nix/catalog.toml` by hand) so each `[[tool]]` has a one-line `#` comment (what it does + docs URL), keep install via mise or the existing Docker/Marketplace path, and let `includes/update/non-nix.sh` bump the pin. Document it. Remove with `non-nix:remove`. Monorepo teams use `non-nix:add-local` / `non-nix:remove-local` against `modules/non-nix/catalog.local.toml` instead (committed; `update` refreshes them). The author Cursor rule enforces the comment shape. Consumers still get shipped pin moves only after a release + `copier update`. Vendored agent skills: `skills add … -a cursor -y` from the repo root (project mise PATH), then list the source in `.agents/skills/README.md`; `update` refreshes them via `includes/update/skills.sh`.

## Generated files

| File | Writer | Git |
| --- | --- | --- |
| `.github/workflows/test.yml` | `presets/ci/github_actions/language-matrix.nix` (`ci.github_actions.language-matrix`) | committed |
| `.devcontainer/devcontainer.json` | devenv `devcontainer.enable` | committed |
| `.vscode/extensions.json` | `presets/<lang>/<category>/*.nix` via `stdlib.devenv.load` | gitignored |
| `.serena/project.yml` | `presets/<lang>/<category>/*.nix` via `stdlib.devenv.load` | gitignored |
| `.vscode/settings.json` | `cursor-sync-extensions` / `vscode-sync-extensions` | committed when it changes |
| `.debtmap.toml` | `modules/debtmap/` | gitignored |
| `mise.toml` | `modules/mise/` from `modules/non-nix/catalog.toml` (+ `catalog.local.toml`) | gitignored |
| `.pre-commit-config.yaml` | git-hooks.nix / prek | gitignored |
| `.env` | Copier from `.env.jinja` when keys were pasted | gitignored |

## Documentation site

Published at [devenv4monorepo.github.io](https://devenv4monorepo.github.io/). The app lives in `docs/` (Vite, React, Spectrum web components, markdown via `?raw`, fenced `bash`/`nix` blocks highlighted with [Shiki](https://shiki.style/)). Copier does **not** copy `docs/` or `.github/workflows/pages.yml`.

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

Fetches [endoflife.date](https://endoflife.date) into `modules/languages/catalog.json` and Copier max defaults (`includes/toolchain-latest.yml`). `includes/` is template-only (`_exclude`). The catalog JSON **does** ship with generated monorepos.

## Tests

```bash
bats -r --jobs "$(nproc)" tests
bats tests/setup
bats tests/home
bats tests/copier.bats
test-devenv                  # unit then integration; writes junit/*.xml
test-devenv-unit             # nix-unit + BATS
test-devenv-integration      # nixosTest, actionlint, act
build-act-image              # devenv-act:24.04 for local act
```

| Suite | Role |
| --- | --- |
| `tests/unit/` | Main nix-unit suite: `stdlib/`, `aspects/`, and cross-cutting topics (versions, hooks, matrices, non-nix, …) |
| `tools/**/tests/{unit,integration}/` | Per-tool suites (discovered; not imported into the main suite) |
| `presets/**/tests/{unit,integration}/` | Per-preset suites (discovered) |

### Test layout

- **Main / cross-cutting:** `tests/unit/default.nix` loads topic files from `tests/unit/*.nix`, `tests/unit/stdlib/`, and `tests/unit/aspects/` via `tests/lib/suite.nix` (no hard-coded topic list). Stdlib loader/API tests use **`tests/fixtures/mock-framework/`** (mock tools + presets), not the production `tools/` / `presets/` trees.
- **Per tool / preset:** keep the leaf as `tools/…/<name>.nix` or `presets/…/<name>.nix`. Add a sibling directory `<name>/tests/unit/` (and optionally `integration/`) with `default.nix` plus topic files for **real** leaf coverage. `stdlib.discover` and the devenv preset collector skip `tests/` so suites are never treated as tools or presets.
- **Shared helpers:** `tests/lib/harness.nix`, `tests/lib/suite.nix`, `tests/lib/preset-eval.nix`, `tests/lib/discover-suites.nix`, `tests/lib/mock-framework.nix`.
- **Run one owner suite:** `nix-unit -I nixpkgs=flake:nixpkgs -I devenv4monorepo=$PWD tools/ide/vscode/tests/unit/default.nix`
| `tests/setup/setup.bats` | `setup.sh` (sources the script; `main` guard) |
| `tests/copier.bats` | `copier copy` / `update`; answers omit secret keys; not copied into monorepos |
| `tests/update.bats` | `update` template vs consumer; pin helpers; skills refresher (stubbed `npx`); no live registry |
| `tests/skills.bats` | `.agents/skills/` ↔ `skills-lock.json` consistency; every source attributed in `.agents/skills/README.md` |
| `tests/toolchain-latest.bats` | catalog alignment, no network |
| `tests/home/terminal-lib.bats` | eval `home/terminal-lib.nix` |
| `tests/home/bashrc-d.bats` | `ensure-bashrc-d.sh` (Ubuntu `~/.bashrc` + `~/.bashrc.d`) |
| `tests/home/cursor-llm.bats` | `home/ides/merge-cursor-llm.sh` + MCP catalog merge (Serena, Headroom MCP, Context7, optional Brave/Firecrawl; preserves user MCP keys; retires github/docker; legacy RTK hook/allowlist cleanup) |
| `tests/home/ensure-serena-config.bats` | `home/ides/ensure-serena-config.py` merges global `excluded_tools: [search_for_pattern]` without wiping Serena-managed keys |
| `tests/home/load-secrets.bats` | `home-switch` SecretSpec export vs `.env` fallback |
| `tests/home/watch-mcp-secrets.bats` | secret fingerprint skip / upsert (Cursor `mcp.json`) |
| `tests/home/docker-rootless.bats` | `DOCKER_HOST` defaults to the rootless socket; CI is a no-op |
| `tests/tag-hook.bats` | failing suite blocks `git tag` |
| `tests/integration/` | nixosTest (generated `test.yml` + eval asserts) |

`test-devenv-integration` `actionlint`s generated `test.yml` and fixtures, then `act workflow_call` on the Python fixture. Skip nested act when `ACT` is set. `.actrc` maps `ubuntu-24.04` and `ubuntu-26.04` to `devenv-act:24.04` (no `act-26.04` image yet). `.github/actionlint.yaml` lists `ubuntu-26.04` until actionlint's built-in runner list includes it.

## Commits and tags

One topic per commit. Subjects must pass `commitlint` (`@commitlint/config-conventional`) so semantic-release can version from `master`/`main`.

```
<type>: <imperative summary>
```

Types: `feat`, `fix`, `docs`, `ci`, `test`, `chore`. Breaking changes use a `BREAKING CHANGE:` footer.

`prek` runs `pre-commit` and `commit-msg`. `hooks/reference-transaction` (installed on `enterShell`) runs the suite when a tag is created or force-moved. `DEVENV_SKIP_TAG_TESTS=1 git tag …` bypasses it. The hook is a no-op when `CI` or `GITHUB_ACTIONS` is set.

## Copier exclusions

`copier.yml` `_exclude` replaces Copier’s defaults. Keep generated noise **and** template-only paths: `includes`, `docs`, `tests/copier.bats`, `.github/workflows/pages.yml`, `.cursor/rules/non-nix-update.mdc`, `/flake.nix`, `/flake.lock`, `/stdlib`, `/packaging`. Copier applies those patterns to the destination path, so the consumer flake is rendered as `consumer-flake.nix` and `_tasks` moves it to `flake.nix`. If you add another template-only path, exclude it and assert that in `tests/copier.bats`.

`_skip_if_exists` leaves a destination `README.md` alone. Questionnaire output is `devenv.local.nix`, not a Jinja `devenv.nix`.

## Repository layout

| Path | Role |
| --- | --- |
| `setup.sh` | Host bootstrap (Nix, devenv, Cachix, Home Manager) |
| `copier.yml` | Questions and `_exclude` (not copied) |
| `devenv.local.nix.jinja` | Renders consumer `devenv.local.nix` |
| `includes/` | Catalog refresh, Copier max YAML, and pin refreshers (`includes/update/non-nix.sh`, `skills.sh`; not copied) |
| `modules/non-nix/` | Shipped `catalog.toml`, `edit-catalog.sh`, optional `catalog.local.toml` (monorepo), resolve/TOML helpers |
| `modules/mise/` | Project `mise.toml` + `mise:install` |
| `home/mise.nix` | User mise conf.d + activation install/pull |
| `.cursor/rules/worktrees-and-stacked-prs.mdc` | One worktree+branch per feature; stack related PRs with `gh stack` (copied) |
| `.cursor/rules/update.mdc` | Consumer rule: `update` vs `copier update` (copied) |
| `.cursor/rules/nix-module-split.mdc` | Split long or duplicated Nix modules; topical `modules/` layout (copied) |
| `.cursor/rules/headroom-compress.mdc` | Call Headroom MCP only for large blobs (copied; `~/.cursor/rules/` after `home-switch`) |
| `.cursor/rules/navi-cheatsheets.mdc` | Prefer extending `cheats/*.cheat`; navi syntax (copied) |
| `.cursor/rules/non-nix-update.mdc` | Author pin/refresher rule (not copied) |
| `.agents/skills/` / `skills-lock.json` | Vendored Cursor skills (Vercel skills CLI; `includes/update/skills.sh` refreshes; copied) |
| `cheats/` | Repo-local navi sheets (`NAVI_PATH` via `devenv shell`; copied) |
| `modules/languages/catalog.json` | Cycle → latest patch and EOL (copied) |
| `modules/update/` | `update` script (template pins vs consumer lock; copied) |
| `docs/` | Pages site (not copied) |
| `devenv.nix` / `devenv.yaml` / `devenv.lock` | Shell, inputs, lock |
| `flake.nix` | Publisher flake (template repo only). Outputs `stdlib` and `lib` are the devenv-stdlib attrset |
| `consumer-flake.nix.jinja` | Consumer flake template. `_tasks` moves the render onto `flake.nix` |
| `stdlib/` | `mkTool`, `mkPreset`, `den.load`, `devenv.load`, `version.nix` (not copied) |
| `packaging/den-outputs.nix` | Den flake body. Publisher passes `root = ./.`; consumers import it from the pin |
| `presets/omer.nix` | Preset names this template enables (copied) |
| `modules/{aspects,den}/` | Den Home Manager composition (import-tree) |
| `home/` | Home Manager modules |
| `home/navi.nix` | `NAVI_PATH` → pinned denisidoro/cheats |
| `home/ides/` | Editors (Cursor, opt-in VS Code, neovim via nixvim, nano), MCP catalog, Cursor LLM context |
| `tools/ide/neovim.nix` | Global `neovim` tool → `programs.nixvim` (flake input `nixvim`) |
| `presets/ide/neovim.nix` | Thin preset attrpath `ide.neovim` (one-tool; hub `ide` still bundles) |
| `secretspec.toml` | Optional `BRAVE_API_KEY` / `FIRECRAWL_API_KEY` / `FIRECRAWL_MCP_PROFILE` (copied) |
| `home/load-secrets.sh` | `secretspec export` then `.env`; used by `home-switch` |
| `home/watch-mcp-secrets.sh` | Re-upsert Brave/Firecrawl MCP when SecretSpec keys change |
| `home/nix-path.sh` | `nixpkgs=flake:nixpkgs` fallback, drops missing `NIX_PATH` dirs; used by `setup.sh`, `home-switch`, `test-devenv` |
| `home/docker-rootless.sh` | Default `DOCKER_HOST` to `$XDG_RUNTIME_DIR/docker.sock` |
| `.env.jinja` | Renders gitignored `.env` when Copier was given those keys |
| `stdlib/` | Framework API (`default.nix`, `version.nix`, categories, harness foundations). Import path is `stdlib`, not `lib/` |
| `modules/` | Barrel `devenv.nix` plus topical packages, languages, ides, hooks, debtmap, mise, non-nix, update, test, lib |
| `hooks/reference-transaction` | Tag guard |
| `commitlint.config.mjs` / `.releaserc.json` | Commits and releases |
| `tests/` | nix-unit, BATS, nixosTest, act image |
| `devenv.local.nix.example` / `home.local.nix.example` / `catalog.local.toml.example` | Extra options / team tools template |

## Local overrides

In **this** repo, `devenv.local.nix` and `home.local.nix` stay gitignored. Put host-only Home Manager lines in `home.local.nix`. Do not commit language enables here.

In a **generated** monorepo, commit `devenv.local.nix`, and add extras below the Copier block (`devenv.local.nix.example`).
