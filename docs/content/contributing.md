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

`setup.sh` installs Nix, devenv, Cachix (`cachix use devenv`), and Home Manager, then applies `home.nix`. After Alacritty, log out and back in once so GNOME Shell loads Quake Terminal.

`home-switch` re-applies Home Manager after you edit `home.nix` or `home.local.nix`.

## Daily loop

```bash
devenv shell                 # or direnv allow once
# edit modules/, home/, copier.yml, docs/content/, …
devenv test                  # enterTest + BATS
test-devenv                  # nix-unit, BATS, nixosTest, actionlint, act
devenv update git-hooks      # refresh only the git-hooks lock input
```

`direnv allow` uses the committed `.envrc`. Alternatively `eval "$(devenv hook bash)"` plus `devenv allow`.

Do not edit `.devenv/` or other generated files. User-facing Nix is `devenv.nix`, `devenv.yaml`, `home.nix`, `modules/`, and `home/`.

`modules/` is topical (`hooks/`, `languages/`, `debtmap/`, `packages/`, `update/`, `test/`, `lib/`). `modules/devenv.nix` is the barrel. Prefer small focused files over growing grab-bags; the Cursor rule `.cursor/rules/nix-module-split.mdc` (copied) requires a split when a module mixes concerns, grows past ~100 lines, or duplicates patterns in the same directory. Obvious cuts land in the same change; large ambiguous moves need a proposed tree first.

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

`update` in this checkout does **not** run a full `devenv update`. Lock policy stays: `git-hooks` weekly; nixpkgs only when intended.

When adding a non-Nix tool to the **template**: run `devenv tasks run non-nix:add -- …` (or edit `modules/non-nix/catalog.toml` by hand) so each `[[tool]]` has a one-line `#` comment (what it does + docs URL), keep install via mise or the existing Docker/Marketplace path, and let `includes/update/non-nix.sh` bump the pin. Document it. Remove with `non-nix:remove`. Monorepo teams use `non-nix:add-local` / `non-nix:remove-local` against `modules/non-nix/catalog.local.toml` instead (committed; `update` refreshes them). The author Cursor rule enforces the comment shape. Consumers still get shipped pin moves only after a release + `copier update`. Vendored agent skills: `skills add … -a cursor -y` from the repo root (project mise PATH), then list the source in `.agents/skills/README.md`; `update` refreshes them via `includes/update/skills.sh`.

## Generated files

| File | Writer | Git |
| --- | --- | --- |
| `.github/workflows/test.yml` | `modules/languages/versions.nix` | committed |
| `.vscode/extensions.json` | `modules/languages/cursor.nix` | gitignored |
| `.serena/project.yml` | `modules/languages/serena.nix` | gitignored |
| `.vscode/settings.json` | `cursor-sync-extensions` | committed when it changes |
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
bats -r tests
bats tests/setup
bats tests/home
bats tests/copier.bats
test-devenv                  # also writes junit/*.xml
build-act-image              # devenv-act:24.04 for local act
```

| Suite | Role |
| --- | --- |
| `tests/unit/` | nix-unit (versions, hooks, debtmap, Cursor, Serena, terminal, …) |
| `tests/setup/setup.bats` | `setup.sh` (sources the script; `main` guard) |
| `tests/copier.bats` | `copier copy` / `update`; `ninerouter` default false; answers omit secret keys; not copied into monorepos |
| `tests/update.bats` | `update` template vs consumer; pin helpers; skills refresher (stubbed `npx`); no live registry |
| `tests/skills.bats` | `.agents/skills/` ↔ `skills-lock.json` consistency; every source attributed in `.agents/skills/README.md` |
| `tests/toolchain-latest.bats` | catalog alignment, no network |
| `tests/home/terminal-lib.bats` | eval `home/terminal-lib.nix` |
| `tests/home/bashrc-d.bats` | `ensure-bashrc-d.sh` (Ubuntu `~/.bashrc` + `~/.bashrc.d`) |
| `tests/home/cursor-llm.bats` | Cursor `hooks.json` / `mcp.json` / `permissions.json` merge (RTK add/remove, `rtk` allowlist upsert, Serena, Headroom MCP without proxy URL, Context7, GitHub, Docker, optional Brave/Firecrawl) |
| `tests/home/configure-9router.bats` | 9Router settings (`headroomEnabled` false) + Brave/Firecrawl upsert + devenv gateway key (fake curl) |
| `tests/home/ninerouter-start.bats` | persist INITIAL_PASSWORD as a 9Router bcrypt hash (tunnel gate); in-container loopback proxy for local-only dashboard routes |
| `tests/home/load-secrets.bats` | `home-switch` SecretSpec export vs `.env` fallback |
| `tests/home/watch-9router-secrets.bats` | secret fingerprint skip / upsert (Cursor `mcp.json`; skip `configure_9router` when 9Router is off) |
| `tests/home/docker-rootless.bats` | `DOCKER_HOST` defaults to the rootless socket; CI is a no-op |
| `tests/tag-hook.bats` | failing suite blocks `git tag` |
| `tests/integration/` | nixosTest (generated `test.yml` + eval asserts) |

`test-devenv` `actionlint`s generated `test.yml` and fixtures, then `act workflow_call` on the Python fixture. Skip nested act when `ACT` is set. `.actrc` maps `ubuntu-24.04` and `ubuntu-26.04` to `devenv-act:24.04` (no `act-26.04` image yet). `.github/actionlint.yaml` lists `ubuntu-26.04` until actionlint's built-in runner list includes it.

## Commits and tags

One topic per commit. Subjects must pass `commitlint` (`@commitlint/config-conventional`) so semantic-release can version from `master`/`main`.

```
<type>: <imperative summary>
```

Types: `feat`, `fix`, `docs`, `ci`, `test`, `chore`. Breaking changes use a `BREAKING CHANGE:` footer.

`prek` runs `pre-commit` and `commit-msg`. `hooks/reference-transaction` (installed on `enterShell`) runs the suite when a tag is created or force-moved. `DEVENV_SKIP_TAG_TESTS=1 git tag …` bypasses it. The hook is a no-op when `CI` or `GITHUB_ACTIONS` is set.

## Copier exclusions

`copier.yml` `_exclude` replaces Copier’s defaults. Keep generated noise **and** template-only paths: `includes`, `docs`, `tests/copier.bats`, `.github/workflows/pages.yml`, `.cursor/rules/non-nix-update.mdc`. If you add another template-only path, exclude it and assert that in `tests/copier.bats`.

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
| `.cursor/rules/worktrees-and-stacked-prs.mdc` | One worktree+branch per feature; stack related PRs infra-first (copied) |
| `.cursor/rules/update.mdc` | Consumer rule: `update` vs `copier update` (copied) |
| `.cursor/rules/nix-module-split.mdc` | Split long or duplicated Nix modules; topical `modules/` layout (copied) |
| `.cursor/rules/headroom-compress.mdc` | Call Headroom MCP only for large blobs (copied; `~/.cursor/rules/` after `home-switch` when 9Router is off) |
| `.cursor/rules/rtk-passthrough.mdc` | Retry once without RTK compaction when a detail is missing (copied; `~/.cursor/rules/` when 9Router is off) |
| `.cursor/rules/non-nix-update.mdc` | Author pin/refresher rule (not copied) |
| `.agents/skills/` / `skills-lock.json` | Vendored Cursor skills (Vercel skills CLI; `includes/update/skills.sh` refreshes; copied) |
| `modules/languages/catalog.json` | Cycle → latest patch and EOL (copied) |
| `modules/update/` | `update` script (template pins vs consumer lock; copied) |
| `docs/` | Pages site (not copied) |
| `devenv.nix` / `devenv.yaml` / `devenv.lock` | Shell, inputs, lock |
| `home.nix` / `home/` | Home Manager |
| `home/llm-context.nix` | Cursor LLM context (Pro: RTK + Ponytail + Headroom MCP; optional 9Router) |
| `home/copier-llm.nix.jinja` | Renders `home/copier-llm.nix` (`cursor.ninerouter.enable`) |
| `secretspec.toml` | Optional `INITIAL_PASSWORD` / `BRAVE_API_KEY` / `FIRECRAWL_API_KEY` (copied) |
| `home/load-secrets.sh` | `secretspec export` then `.env`; used by `home-switch` |
| `home/nix-path.sh` | `nixpkgs=flake:nixpkgs` fallback, drops missing `NIX_PATH` dirs; used by `setup.sh`, `home-switch`, `test-devenv` |
| `home/docker-rootless.sh` | Default `DOCKER_HOST` to `$XDG_RUNTIME_DIR/docker.sock` |
| `.env.jinja` | Renders gitignored `.env` when Copier was given those keys |
| `modules/` | Barrel `devenv.nix` plus topical packages, languages, hooks, debtmap, mise, non-nix, update, test, lib |
| `hooks/reference-transaction` | Tag guard |
| `commitlint.config.mjs` / `.releaserc.json` | Commits and releases |
| `tests/` | nix-unit, BATS, nixosTest, act image |
| `devenv.local.nix.example` / `home.local.nix.example` / `catalog.local.toml.example` | Extra options / team tools template |

## Local overrides

In **this** repo, `devenv.local.nix` and `home.local.nix` stay gitignored. Put host-only Home Manager lines in `home.local.nix`. Do not commit language enables here.

In a **generated** monorepo, commit `devenv.local.nix` and `home/copier-llm.nix`, and add extras below the Copier block (`devenv.local.nix.example`).
