# Architecture

Three layers, three lifetimes. Mixing them is what makes a devenv-on-the-laptop feel fragile.

```
published package (this flake)  --flake pin-->  consumer working tree
                                                      |
                                                      | devenv shell
                                                      v
                                                project PATH
                                                      ^
host (Ubuntu 24.04 or 26.04 LTS)  --home-switch-->  user profile (terminal, Cursor, CLIs)
```

## Three layers

**Package (this git repo).** The publishable devenv-stdlib flake (`outputs.stdlib` ≡ `outputs.lib`), framework sources under `stdlib/`, shippable `presets/` and `tools/`, packaging helpers, the toolchain catalog, and the docs site. You develop the package here. Consumers take framework code from the flake pin — they do not vendor `stdlib/` or `packaging/` by copying this tree.

**Consumer (the destination monorepo).** Pins `inputs.devenv-stdlib`, imports `${inputs.devenv-stdlib}/packaging/den-outputs.nix` with `root = ./.` (consumer overlay only; framework modules/home/tools resolve from the pin), loads framework presets from the pin plus local `./presets`, and owns `devenv.local.nix` / `home.local.nix`. `devenv shell` is the project toolchain: git hooks, language versions, generated `.github/workflows/test.yml`. Leaving the directory (or `direnv`) drops that PATH.

**Host (the person).** Home Manager applies the Den `homeConfigurations.developer` profile (`home-switch`). The dropdown terminal, Starship, Cursor, `rg`, `fd`, `gh`, and the other user-global CLIs stay available after you `cd` away. `setup.sh` installs Nix, devenv, Cachix, and Home Manager once per machine. Supported hosts are the current Ubuntu LTS and the previous one, with **rootless Docker** as the default Engine (local `act`). GitHub Actions keeps the runner’s rootful daemon. Den also declares **stub** `den.hosts` for NixOS/Darwin class matrices (`shell-tools` portable aspect); GNOME quake terminals stay Ubuntu/HM-only — see `modules/den/MULTI-OS.md`.

The terminal is user-global because you already have a terminal open to run `devenv shell`. Putting Alacritty on the project PATH would hide it the moment you leave the repo.

## How a consumer wires the pin

1. Add `devenv-stdlib.url = "github:thedrow/devenv4monorepo/<tag-or-sha>"` (see `consumer-flake.nix.example`).
2. Import `${inputs.devenv-stdlib}/packaging/den-outputs.nix` with `stdlib = inputs.devenv-stdlib.stdlib` and `root = ./.` (overlay). Framework Den modules and cache presets come from the pin (`frameworkRoot`), not from copied paths under `root`.
3. Load `"${inputs.devenv-stdlib}/presets"` and local `./presets` (later paths override).
4. Enable languages and version bounds in committed `devenv.local.nix` (start from `devenv.local.nix.example`). In this publisher checkout that file stays gitignored so experiments do not leak.
5. Optional secrets go to SecretSpec / `.env` — not into the flake URL.

`devenv.nix` stays a real Nix file. Extra options (debtmap thresholds, extra packages, `supported.*.max`) live in `devenv.local.nix`; see `devenv.local.nix.example`.

Bump the flake input (and `flake.lock`) when you want a newer framework revision.

## How devenv evaluates the tree

`devenv.yaml` pins inputs and imports `modules/devenv.nix` (Den lives beside it under `modules/{aspects,den}/`, loaded by flake `import-tree`). Evaluation reads `languages.*` and `supported.*` from `devenv.local.nix` (when the file exists):

- Language packs, IDE `.vscode/extensions.json`, Serena `.serena/project.yml` `language_servers`, and language linters follow `languages.*` via `presets/<lang>/<category>/*.nix` (`stdlib.devenv.load`). Cross-cutting linters are first-class under `linters.*` (parallel to `languages.*`) and mostly run through [treefmt](https://devenv.sh/integrations/treefmt/); residual checks stay on prek — see [Hooks](hooks.md).
- CI versions follow `supported.<lang>.min` / `max` / `unsupported` / `versions`. When min/max omit a patch (`3.12`, `22`), `modules/languages/catalog.json` supplies the latest **non-EOL** patch of each cycle in range. `refresh-toolchain-latest` rebuilds that catalog from [endoflife.date](https://endoflife.date).
- `enterShell` does **not** write git-tracked generated files. It dry-runs them and the stdlib status report names the task when a file is stale (`ci:update-language-matrix`, `ci:update-anti-slop`, `ci:update-pr-metrics`, `ci:update-aletheore`, `ides:update-extensions-json`, `ides:update-settings-json`, or `stdlib:update-generated` for all). `cursor-sync-extensions` still links language packs under `~/.cursor/extensions` (not git-tracked). devenv `files` still writes gitignored `.serena/project.yml`, `.debtmap.toml`, and `mise.toml`. `.devcontainer/devcontainer.json` is devenv `devcontainer.enable` (committed). [prek](https://prek.j178.dev/) manages `pre-commit` and `commit-msg` only (generated `.pre-commit-config.yaml` is gitignored).

## How Home Manager stays out of the project PATH

Den owns HM composition: `den.homes` + aspects (`cursor`, `terminal`, `home-cli`) land in `homeConfigurations.developer`. `home-switch` is `home-manager switch -b backup --flake .#developer --impure`. Optional host overrides live in `home.local.nix` (`mkForce`). That is a user profile, not a devenv generation. Bash integrations land in `~/.bashrc.d/` (including `mise activate`); Ubuntu's `~/.bashrc` only sources that directory so a distro upgrade does not have to be merged by hand. When `cursor.llmContext.enable` is on (default: `cursor.enable`), the same switch installs catalog CLIs via mise (or Nix when promotable)—Serena, Headroom MCP, git-conflict-mcp, git-rebase-mcp, optional [Aletheore](https://www.aletheore.com) MCP (`cursor.llmContext.aletheore.enable`; dogfood default on in this template)—merges Cursor MCP from the shared `home/ides/mcp` catalog into `~/.cursor/mcp.json` (upsert only; user-added servers stay), merges `search_for_pattern` into `~/.serena/serena_config.yml` `excluded_tools`, writes Ponytail and Headroom rules, and starts `mcp-secrets-watch` so Brave/Firecrawl re-upsert when SecretSpec keys change (wrappers under `~/.config/devenv4monorepo/`).

Language packs are the exception: they are **not** user-global. Language tool presets (`presets/<lang>/<category>/*.nix`, loaded by `stdlib.devenv.load`) generate `.vscode/extensions.json`, settings, Serena `language_servers`, and language git hooks from `languages.*`. Cascade fan-out (“what does `python` enable?”) is Den aspect `includes` (`modules/den/_cascades/language-cascade.nix`); enable flags still come from `languages.*.enable`. `cursor-sync-extensions` installs the matching packs under `~/.cursor/extensions` when you enter the shell (add-only; user extensions stay). `vscode.enable` (default **false**) is opt-in for the VS Code app and `~/.vscode/extensions` common links. Global Serena `excluded_tools` (e.g. `search_for_pattern`) come from `home-switch` via `home/ides/ensure-serena-config.py`, not from the project file.

## Release loop

Conventional Commits (`commitlint`) on every commit. `ci.yml` on pull requests and on push to `master`/`main` runs **Lint (prek)** first (`prek run --all-files`, including the `treefmt` hook; [pre-commit.ci lite](https://pre-commit.ci/lite.html) pushes autofixes on PRs, including forks), then unit and integration suites, then the generated `test.yml` matrix; push to `master`/`main` also runs [semantic-release](https://semantic-release.gitbook.io/semantic-release/) which versions and tags. Those tags are what consumers pin by default once releases exist. When enabled, pull requests also run `pr-quality.yml` ([peakoss/anti-slop](https://github.com/marketplace/actions/anti-slop) on `pull_request` — this dogfood checkout sets `presets.ci.github_actions.anti-slop.enable = true`) and `aletheore.yml` ([Aletheore](https://www.aletheore.com) evidence-grounded PR diffs).


The tag guard blocks a local `git tag` if tests fail. Semantic-release in GitHub Actions sets `CI` / `GITHUB_ACTIONS`, so the hook is a no-op there.
