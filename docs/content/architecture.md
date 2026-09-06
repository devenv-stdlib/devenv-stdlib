# Architecture

Three layers, three lifetimes. Mixing them is what makes a devenv-on-the-laptop feel fragile.

```
this template  --copier copy/update-->  monorepo working tree
                                              |
                                              | devenv shell
                                              v
                                        project PATH
                                              ^
host (Ubuntu 24.04 or 26.04 LTS)  --home-switch-->  user profile (terminal, Cursor, CLIs)
```

## Three layers

**Template (this git repo).** Copier questions (`copier.yml`), the toolchain catalog, the docs site, and the shared Nix modules. You develop the template here. `docs/` and `.github/workflows/pages.yml` stay here; Copier does not copy them into monorepos.

**Monorepo (the destination).** After `copier copy`, the tree has `devenv.nix`, `devenv.yaml`, `modules/`, `home.nix`, `setup.sh`, and a generated `devenv.local.nix`. `devenv shell` is the project toolchain: git hooks, language versions, generated `.github/workflows/test.yml`. Leaving the directory (or `direnv`) drops that PATH.

**Host (the person).** Home Manager applies `home.nix` into the user profile. The dropdown terminal, Starship, Cursor, `rg`, `fd`, `gh`, and the other user-global CLIs stay available after you `cd` away. `setup.sh` installs Nix, devenv, Cachix, and Home Manager once per machine. Supported hosts are the current Ubuntu LTS and the previous one, with **rootless Docker** as the default Engine (local `act`, 9Router). GitHub Actions keeps the runner’s rootful daemon.

The terminal is user-global because you already have a terminal open to run `devenv shell`. Putting Alacritty on the project PATH would hide it the moment you leave the repo.

## How Copier wires a monorepo

1. `copier copy` (latest tag, or `--vcs-ref HEAD` for this checkout) asks for the devenv shell name, which languages to enable, min/max versions, the Rust edition when Rust is on, and the options those languages require.
2. `devenv.local.nix.jinja` renders `devenv.local.nix`. That file is **committed in the monorepo** and **gitignored in this template repo**, so the template itself never enables a language by accident.
3. `.copier-answers.yml` is rendered from `{{_copier_conf.answers_file}}.jinja`. Brave/Firecrawl keys are omitted; the file stores `brave_search` / `firecrawl` booleans instead. Do not edit it by hand; `copier update` needs it.
4. An existing destination `README.md` is left in place (`_skip_if_exists`).
5. `copier.yml`, `includes/`, `docs/`, `tests/copier.bats`, `pages.yml`, and `.cursor/rules/non-nix-update.mdc` are in `_exclude` and do not land in the copy.

`devenv.nix` stays a real Nix file (not Jinja). Questionnaire answers only write `devenv.local.nix`. Extra options (debtmap thresholds, extra packages, `supported.*.max`) go below the generated block; see `devenv.local.nix.example`.

`copier update` re-asks the questions and merges the template. Keep the destination working tree clean. Inline conflict markers fail `check-merge-conflicts` (`--assume-in-merge`, so Copier markers count).

## How devenv evaluates the tree

`devenv.yaml` pins inputs and imports `modules/`. Evaluation reads `languages.*` and `supported.*` from `devenv.local.nix` (when the file exists):

- Language packs, Cursor `.vscode/extensions.json`, Serena `.serena/project.yml` `language_servers`, and language git hooks follow `languages.*`.
- CI versions follow `supported.<lang>.min` / `max` / `unsupported` / `versions`. When min/max omit a patch (`3.12`, `22`), `modules/toolchain-catalog.json` supplies the latest **non-EOL** patch of each cycle in range. `refresh-toolchain-latest` rebuilds that catalog from [endoflife.date](https://endoflife.date).
- `enterShell` writes `.github/workflows/test.yml` (**committed**), `.debtmap.toml`, `.vscode/extensions.json`, and `.serena/project.yml` (gitignored), installs `hooks/reference-transaction`, and runs `cursor-sync-extensions`. [prek](https://prek.j178.dev/) manages `pre-commit` and `commit-msg` only (generated `.pre-commit-config.yaml` is gitignored).

## How Home Manager stays out of the project PATH

`home.nix` imports `home/*.nix`, optional `home/copier-llm.nix` (Copier `ninerouter` → `cursor.ninerouter.enable`), then optional `home.local.nix` (`mkForce`). `home-switch` is `home-manager switch -b backup -f home.nix`. That is a user profile, not a devenv generation. Bash integrations land in `~/.bashrc.d/`; Ubuntu's `~/.bashrc` only sources that directory so a distro upgrade does not have to be merged by hand. When `cursor.llmContext.enable` is on and `cursor.ninerouter.enable` is off (default), the same switch installs RTK, Serena, and Headroom MCP, merges Cursor hooks/MCP (Context7, GitHub, Docker, optional Brave/Firecrawl), and does not start 9Router or write a Models override — Cursor Pro stays usable. When `cursor.ninerouter.enable` is on, it starts 9Router only (built-in RTK/Ponytail; no host Headroom) and Agent chat uses that gateway only after you set Override OpenAI Base URL to `http://127.0.0.1:20128/v1` and select a 9Router model (Home Manager cannot write those GUI fields; Pro models fail while the key toggle is on). `ninerouter-secrets-watch` re-upserts Brave/Firecrawl into `~/.cursor/mcp.json` (and into 9Router when the gateway is on) when SecretSpec keys change.

Language packs are the exception: they are **not** user-global. devenv generates `.vscode/extensions.json` and `.serena/project.yml` from `languages.*`. `cursor-sync-extensions` installs the matching Cursor extensions when you enter the shell. Serena reads `language_servers` and starts its own LSPs.

## Release loop

Conventional Commits (`commitlint`) on every commit. Pull requests run `hooks.yml` (`prek`; [pre-commit.ci lite](https://pre-commit.ci/lite.html) pushes autofixes, including forks). Push to `master` or `main` runs `ci.yml`: `test-devenv`, then the generated `test.yml` matrix, then [semantic-release](https://semantic-release.gitbook.io/semantic-release/) which versions and tags. Those tags are what `copier copy` and `copier update` use by default.

The tag guard blocks a local `git tag` if tests fail. Semantic-release in GitHub Actions sets `CI` / `GITHUB_ACTIONS`, so the hook is a no-op there.
