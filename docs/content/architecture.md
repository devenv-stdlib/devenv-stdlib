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

**Monorepo (the destination).** After `copier copy`, the tree has `devenv.nix`, `devenv.yaml`, `modules/`, Den flake (`flake.nix` + `den/`), `setup.sh`, and a generated `devenv.local.nix`. `devenv shell` is the project toolchain: git hooks, language versions, generated `.github/workflows/test.yml`. Leaving the directory (or `direnv`) drops that PATH.

**Host (the person).** Home Manager applies the Den `homeConfigurations.developer` profile (`home-switch`). The dropdown terminal, Starship, Cursor, `rg`, `fd`, `gh`, and the other user-global CLIs stay available after you `cd` away. `setup.sh` installs Nix, devenv, Cachix, and Home Manager once per machine. Supported hosts are the current Ubuntu LTS and the previous one, with **rootless Docker** as the default Engine (local `act`, Docker MCP). GitHub Actions keeps the runner’s rootful daemon.

The terminal is user-global because you already have a terminal open to run `devenv shell`. Putting Alacritty on the project PATH would hide it the moment you leave the repo.

## How Copier wires a monorepo

1. `copier copy` (latest tag, or `--vcs-ref HEAD` for this checkout) asks for the devenv shell name, which languages to enable, min/max versions, the Rust edition when Rust is on, and the options those languages require.
2. `devenv.local.nix.jinja` renders `devenv.local.nix`. That file is **committed in the monorepo** and **gitignored in this template repo**, so the template itself never enables a language by accident.
3. `.copier-answers.yml` is rendered from `{{_copier_conf.answers_file}}.jinja`. Brave/Firecrawl keys are omitted; the file stores `brave_search` / `firecrawl` booleans instead. Do not edit it by hand; `copier update` needs it.
4. An existing destination `README.md` is left in place (`_skip_if_exists`).
5. `copier.yml`, `includes/`, `docs/`, `tests/copier.bats`, `pages.yml`, and `.cursor/rules/non-nix-update.mdc` are in `_exclude` and do not land in the copy. `.agents/skills/` and `skills-lock.json` **do** copy; they are the vendored Cursor skills.

`devenv.nix` stays a real Nix file (not Jinja). Questionnaire answers only write `devenv.local.nix`. Extra options (debtmap thresholds, extra packages, `supported.*.max`) go below the generated block; see `devenv.local.nix.example`.

`copier update` re-asks the questions and merges the template. Keep the destination working tree clean. Inline conflict markers fail `check-merge-conflicts` (`--assume-in-merge`, so Copier markers count).

## How devenv evaluates the tree

`devenv.yaml` pins inputs and imports `modules/`. Evaluation reads `languages.*` and `supported.*` from `devenv.local.nix` (when the file exists):

- Language packs, IDE `.vscode/extensions.json` (`modules/ides`), Serena `.serena/project.yml` `language_servers`, and language git hooks follow `languages.*`.
- CI versions follow `supported.<lang>.min` / `max` / `unsupported` / `versions`. When min/max omit a patch (`3.12`, `22`), `modules/languages/catalog.json` supplies the latest **non-EOL** patch of each cycle in range. `refresh-toolchain-latest` rebuilds that catalog from [endoflife.date](https://endoflife.date).
- `enterShell` writes `.github/workflows/test.yml` (**committed**), `.debtmap.toml`, `mise.toml`, `.vscode/extensions.json`, and `.serena/project.yml` (gitignored), installs `hooks/reference-transaction`, and runs `cursor-sync-extensions`. [prek](https://prek.j178.dev/) manages `pre-commit` and `commit-msg` only (generated `.pre-commit-config.yaml` is gitignored).

## How Home Manager stays out of the project PATH

Den owns HM composition: `den.homes` + aspects (`cursor`, `terminal`, `home-cli`) land in `homeConfigurations.developer`. `home-switch` is `home-manager switch -b backup --flake .#developer --impure`. Optional host overrides live in `home.local.nix` (`mkForce`). That is a user profile, not a devenv generation. Bash integrations land in `~/.bashrc.d/` (including `mise activate`); Ubuntu's `~/.bashrc` only sources that directory so a distro upgrade does not have to be merged by hand. When `cursor.llmContext.enable` is on (default: `cursor.enable`), the same switch installs catalog CLIs via mise (or Nix when promotable)—Serena, Headroom MCP, git-conflict-mcp, git-rebase-mcp—merges Cursor MCP from the shared `home/ides/mcp` catalog into `~/.cursor/mcp.json` (upsert only; user-added servers stay), writes Ponytail and Headroom rules, and starts `mcp-secrets-watch` so Brave/Firecrawl re-upsert when SecretSpec keys change (wrappers under `~/.config/devenv4monorepo/`).

Language packs are the exception: they are **not** user-global. devenv (`modules/ides`) generates `.vscode/extensions.json` and settings from `languages.*`. Cascade fan-out (“what does `python` enable?”) is Den aspect `includes` (`den/language-cascade.nix`); Copier still only flips `languages.*.enable`. `cursor-sync-extensions` installs the matching packs under `~/.cursor/extensions` when you enter the shell (add-only; user extensions stay). `vscode.enable` (default **false**) is opt-in for the VS Code app and `~/.vscode/extensions` common links. Serena’s project `language_servers` still come from `modules/languages/serena.nix`.

## Release loop

Conventional Commits (`commitlint`) on every commit. Pull requests run `hooks.yml` (`prek`; [pre-commit.ci lite](https://pre-commit.ci/lite.html) pushes autofixes, including forks). Push to `master` or `main` runs `ci.yml`: `test-devenv`, then the generated `test.yml` matrix, then [semantic-release](https://semantic-release.gitbook.io/semantic-release/) which versions and tags. Those tags are what `copier copy` and `copier update` use by default.

The tag guard blocks a local `git tag` if tests fail. Semantic-release in GitHub Actions sets `CI` / `GITHUB_ACTIONS`, so the hook is a no-op there.
