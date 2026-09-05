# devenv4monorepo

Portable [devenv](https://devenv.sh/) configuration for a Linux monorepo toolchain, plus a [Home Manager](https://nix-community.github.io/home-manager/) module for a user-global dropdown terminal and Starship.

This repository is a [Copier](https://copier.readthedocs.io/en/stable) template. A monorepo copies it once, then runs `copier update` when a new tagged release ships. Clone this repo only to develop the template itself.

The dropdown terminal is **not** part of the devenv PATH: you already have a terminal open to enter it.

## Apply to a monorepo

`copier` is on PATH after `home-switch` (Home Manager) or inside `devenv shell`.

```bash
# Latest tagged release (PEP 440). Use this after CI has published tags.
copier copy <template-git-url> path/to/monorepo

# This checkout, including work that is not tagged yet
copier copy --vcs-ref HEAD /path/to/devenv4monorepo path/to/monorepo
```

Copier asks for the devenv shell name and which languages to enable (Rust, Go, Python, JavaScript, TypeScript), then min/max versions and the options those languages require. Each max defaults to the latest stable shipped in `includes/toolchain-latest.yml` (from [endoflife.date](https://endoflife.date), aligned so min and max differ in one component). Leave a max empty for no upper bound. Answers are written to `devenv.local.nix`.

Commit `.copier-answers.yml` and `devenv.local.nix` in the monorepo. Do not edit the answers file by hand. Then `./setup.sh` and `devenv shell`. An existing `README.md` is left in place.

```bash
cd path/to/monorepo
copier update                 # latest Git tag
copier update --vcs-ref HEAD  # template branch
copier check-update           # report whether a newer tag exists
```

Keep the destination git working tree clean before `copier update`. Inline conflict markers are rejected by the `check-merge-conflicts` hook.

## Prerequisites

- Ubuntu 22.04 LTS (x86_64 or aarch64) — the only OS supported in this MVP
- `curl` and a user that can create `/nix` (the Nix installer typically needs `sudo` once)

## Bootstrap on a fresh machine

One command configures the devenv binary cache as root, applies `home.nix` (Alacritty + Zellij + Quake Terminal, Atuin + ble.sh, Cursor + devenv extension, Starship), and builds this environment:

```bash
./setup.sh
```

The script prints a notice that it needs `sudo` for the Nix daemon, flakes (if missing), and `cachix use devenv`. It does **not** add your user to Nix `trusted-users`. Home Manager is installed into the user Nix profile and does not need sudo.

Then enter the project toolchain:

```bash
devenv shell
```

You should see `devenv4monorepo ready: <user>@<hostname>`. After that, `git`, `gh`, `jq`, `rg`, `fd`, `direnv`, `nixfmt`, `bats`, `shellcheck`, `home-manager`, `copier`, and `debtmap` are on `PATH`.

Re-apply the user-global terminal after editing `home.nix` (also done by `./setup.sh`):

```bash
home-switch
```

That is `home-manager switch -b backup -f home.nix`. Existing files Home Manager needs to replace are moved aside with a `.backup` suffix. On flakes-only hosts, `home-switch` and `setup.sh` set `NIX_PATH=nixpkgs=flake:nixpkgs` when `NIX_PATH` has no `nixpkgs=` entry.

## Everyday commands

| Command | Purpose |
| --- | --- |
| `./setup.sh` | Install or update Nix, devenv, Cachix, and Home Manager; apply `home.nix`; build this environment |
| `copier copy <src> <dest>` | Apply this template to a monorepo (latest tag, or `--vcs-ref HEAD`) |
| `copier update` | Pull a newer tagged template into an existing copy |
| `copier check-update` | Report whether a newer template tag exists |
| `refresh-toolchain-latest` | Fetch endoflife.date cycles into `modules/toolchain-catalog.json` and Copier max defaults |
| `devenv shell` | Enter the project toolchain |
| `home-switch` | Re-apply Home Manager after editing `home.nix` (same as the setup.sh HM step) |
| `devenv test` | Build the env, check the toolchain, and run the BATS suite |
| `test-devenv` / `devenv tasks run devenv:test-devenv` | Full suite: nix-unit, BATS, nixosTest, generate `test.yml`, `actionlint` it, `act` the empty workflow and a Python version matrix. Writes `junit/*.xml` |
| `build-act-image` | Build `devenv-act:22.04` (non-root `runner` user) for local `act` |
| `bats -r tests` | Run the BATS suite (setup, copier, toolchain-latest, home/terminal-lib, tag hook) |
| `devenv update` | Refresh `devenv.lock` from `devenv.yaml` inputs |
| `devenv gc` | Delete unused environment generations |

Optional auto-activation:

- **devenv hook** (no extra tools): add `eval "$(devenv hook bash)"` to `~/.bashrc`, then `devenv allow` in this repo.
- **direnv**: Home Manager installs direnv + nix-direnv and hooks bash. `direnv allow` here (`.envrc` is committed).

## Layout

| Path | Role |
| --- | --- |
| `setup.sh` | One-command host bootstrap (Nix, devenv, Cachix, Home Manager, this environment) |
| `copier.yml` | Copier questions and settings (excluded from generated projects) |
| `{{_copier_conf.answers_file}}.jinja` | Renders `.copier-answers.yml` so `copier update` works |
| `devenv.local.nix.jinja` | Renders `devenv.local.nix` from the questionnaire |
| `includes/toolchain-latest.yml` | Latest non-EOL stables used as Copier max-version defaults (not copied into monorepos) |
| `includes/toolchain-latest.py` | Fetches endoflife.date cycles (`refresh-toolchain-latest`) |
| `modules/toolchain-catalog.json` | Cycle → latest patch and EOL, used when min/max omit a patch |
| `.gitignore.jinja` | Consumer gitignore (commits `devenv.local.nix`) |
| `devenv.nix` | Shell banner, Cachix pull, tests, `home-switch` |
| `devenv.yaml` | Inputs, module imports, CLI version pin |
| `devenv.lock` | Pinned inputs (commit this) |
| `home.nix` | Home Manager entry (username from `$USER` / `$HOME`) |
| `home/terminal.nix` | Shared options: `terminal.provider` (default `alacritty`), F12, dash pin |
| `home/alacritty.nix` | Alacritty, Zellij, Quake Terminal, Atuin (daemon-fuzzy), ble.sh |
| `home/cursor.nix` | Cursor IDE launcher (Mesa/X11/--no-sandbox) |
| `home/cursor-extensions.nix` | Common Cursor/VS Code extensions (user-global) |
| `home/vscode-ext-lib.nix` | Shared extension lists (common + Rust/Go/Python/TS) |
| `modules/cursor-languages.nix` | Generates `.vscode/extensions.json` from `languages.*`; installs missing packs |
| `home/nano.nix` | User-global nano with all bundled syntax files |
| `home/neovim.nix` | User-global Neovim (no plugins yet) |
| `home/bat.nix` | User-global bat, `cat` aliased to `bat` |
| `home/eza.nix` | User-global eza; bash integration aliases `ls`/`ll`/`la`/`lt`/`lla` |
| `home/copier.nix` | User-global [copier](https://copier.readthedocs.io/en/stable) CLI (`copy` / `update`) |
| `home/httpie.nix` | User-global `http` / httpie CLI |
| `home/howdoi.nix` | User-global `howdoi` CLI |
| `home/explainshell.nix` | User-global `tldr` (tealdeer; nixpkgs has no explainshell) |
| `home/semantic-release.nix` | User-global `semantic-release` CLI |
| `home/pay-respects.nix` | User-global `fuck` (pay-respects; nixpkgs dropped thefuck) |
| `home/usql.nix` | User-global usql, built with the `all` driver tag |
| `home/zoxide.nix` | User-global `zoxide` (`z`) with bash integration |
| `home/act.nix` | User-global `act` (nektos/act; GitHub Actions locally) |
| `home/fzf.nix` | User-global fzf with bash integration |
| `home/delta.nix` | User-global git + delta pager (`programs.git`) |
| `home/direnv.nix` | User-global direnv + nix-direnv, hooked in bash |
| `home/ripgrep.nix` | User-global `rg` |
| `home/fd.nix` | User-global `fd` |
| `home/gh.nix` | User-global GitHub CLI |
| `home/warp.nix` | Optional Warp provider (VMware-hostile; opt in) |
| `home/terminal-lib.nix` | Keybinding map, desktop entries, Warp settings.toml |
| `home.local.nix.example` | Template for gitignored `home.local.nix` |
| `devenv.local.nix.example` | Template for gitignored `devenv.local.nix` |
| `modules/packages.nix` | Project CLI packages (includes `home-manager`, `commitlint`, `copier`, `debtmap`; `iredis` when `services.redis.enable`) |
| `modules/debtmap-pkg.nix` | [debtmap](https://github.com/iepathos/debtmap) 0.23.0 from official release binaries |
| `modules/debtmap.nix` | Nix options for thresholds; writes generated `.debtmap.toml` |
| `modules/debtmap-lib.nix` | Pure `.debtmap.toml` defaults and language-aware ignore/god-object tables (nix-unit) |
| `modules/git-hooks.nix` | Always: Nix lints, `shellcheck`, `typos`, `proselint`, `lychee`, `actionlint`, `yamlfmt`, `check-json`, `trim-trailing-whitespace`, `end-of-file-fixer`, `check-added-large-files`, `check-case-conflicts`, `check-merge-conflicts`, `gitleaks`, `commitlint`. Language hooks follow `languages.*` |
| `.yamlfmt` | yamlfmt: keep single blank lines; skip generated pre-commit config |
| `.proselintrc.json` | proselint: allow straight quotes and `...` in Markdown |
| `commitlint.config.mjs` | Conventional Commits rules for the commitlint hook |
| `.releaserc.json` | semantic-release plugins (GitHub releases, no npm publish) |
| `modules/languages.nix` | Commented language examples (off by default); optional `python.extensionToolchain`; `pythonTypeChecker` (`pyright` or `ty`); required `typescript.bundler` when TypeScript is on |
| `modules/language-versions.nix` | Required `supported.<lang>.min` (optional max/unsupported) when a language is on; writes `.github/workflows/test.yml` |
| `modules/language-versions-lib.nix` | Pure version-policy and `test.yml` generation (nix-unit) |
| `modules/project-lib.nix` | Pure git-hook, Cursor, debtmap language list, and TypeScript bundler policy (nix-unit) |
| `modules/test-devenv.nix` | `test-devenv` task/script: nix-unit, BATS, nixosTest, `actionlint`, `act`; writes `junit/*.xml` |
| `tests/junit-report.py` | JUnit writer for nix-unit, nixosTest, and BATS (`file`/`line` for PR annotations) |
| `tests/unit/` | nix-unit tests by topic (`versions`, `problems`, `matrices`, `workflow`, `hooks`, `debtmap`, `cursor`, `terminal`) |
| `tests/act/Dockerfile` | act job image: `runner` (uid 1000) with passwordless sudo, so Nix is not installed as root |
| `tests/integration/` | nixosTest (Ubuntu 22.04): workflow contracts, `actionlint` in the guest, plus `workflows.nix` fixtures |
| `tests/setup/setup.bats` | Unit tests for `setup.sh` |
| `tests/copier.bats` | Copier copy/update (template-only; not copied into monorepos) |
| `tests/toolchain-latest.bats` | Align/fetch unit tests for Copier max-version defaults |
| `tests/home/terminal-lib.bats` | Eval tests for `home/terminal-lib.nix` |
| `tests/tag-hook.bats` | Tests that a failing suite really blocks `git tag` |
| `hooks/reference-transaction` | Tag guard, installed into `.git/hooks` on shell entry |
| `devenv.local.nix` | Questionnaire output in generated monorepos; gitignored in this template repo |
| `home.local.nix` | Gitignored Home Manager overrides |

## Local overrides

`copier copy` writes `devenv.local.nix` from the questionnaire (`name`, `languages.*`, `supported.*`). `copier update` re-asks those questions. Add extra options from `devenv.local.nix.example` (debtmap, packages, `supported.*.max`) below the generated block. In this template repo, `devenv.local.nix` stays gitignored so languages remain off while you develop the template.

`python.extensionToolchain` puts `cc`, `c++`, `make`, `pkg-config`, `rustc`, and `cargo` on PATH so pip/uv can compile extensions when wheels or Homebrew bottles are missing. It does not enable `languages.c` / `languages.rust` (no LSP, Cursor language packs, or rust/c git-hooks).

`languages.typescript.enable` requires `typescript.bundler`: `vite`, `turbopack`, `rspack` (legacy webpack apps), `tsup`, or `tsdown`. Evaluation fails until one is set. The bundler itself stays a project `package.json` dependency.

Each enabled language also requires `supported.<lang>.min`. Optional `max` and `unsupported` (versions to skip, for example a Rust ICE) bound the range. When min/max omit a patch (`3.12`, `22`), CI uses the latest patch of each non-EOL cycle in that range from `modules/toolchain-catalog.json` (refresh with `refresh-toolchain-latest`). Evaluation fails if min or max is EOL or missing from the catalog. When a patch is set (`1.80.0`–`1.85.0`), CI still steps the one component that changes (1.80.0, 1.81.0, …), minus `unsupported`. Set `versions` to list them explicitly when min and max differ in more than one component. JavaScript (or TypeScript) must pick at least one of `nodejs`, `bun`, or `deno`. Python is 3+ only, with `cpython` and/or `pypy`. Rust always includes `stable` and may add `beta` / `nightly`. `devenv shell` writes `.github/workflows/test.yml` as a reusable workflow (`workflow_call`) that runs `devenv test` per language per version on Ubuntu 22.04. `ci.yml` runs `test-devenv` first and calls `test.yml` when that file exists. Cross-language matrices (Rust × Python) are not supported yet.

Copy Home Manager options into `home.local.nix` (see `home.local.nix.example`):

```nix
{
  terminal.provider = "warp";
  terminal.quakeKeybinding = "ctrl-`";
}
```

## Terminal and Starship

The dropdown terminal is user-global via Home Manager, not `devenv shell`. The default is [Alacritty](https://alacritty.org/) running [Zellij](https://zellij.dev/), toggled by the [Quake Terminal](https://extensions.gnome.org/extension/6307/quake-terminal/) GNOME extension on **F12**. That stack renders under VMware Workstation; Warp does not.

| Setting | Alacritty (default) | Warp (`terminal.provider = "warp"`) |
| --- | --- | --- |
| Binary | `alacritty` + Zellij | `warp-terminal` (Wayland-wrapped) |
| Dropdown | F12 Quake extension, session `quake`, no decorations | Warp dedicated hotkey window |
| Sidebar / app grid | Normal window, session `main`, decorations on | Warp logo |
| Shortcut | F12 (`terminal.quakeKeybinding`) | same option, via a GNOME custom shortcut |
| Height | 30% (`terminal.heightPercent`) | same option |
| Dash icon | Alacritty (Zellij) — not the dropdown | Warp logo |
| Prompt | Starship via Home Manager `programs.bash` | Starship + `honor_ps1 = true` |
| History | Atuin `search_mode = "daemon-fuzzy"`, user-systemd daemon | Warp's own history |
| Line editor | ble.sh (syntax highlighting), then Atuin | Warp's own editor |

Only the selected provider is installed. Switching also drops the other one's dash icon, desktop file, and shortcut so F12 is not bound twice.

After `home-switch` with Alacritty, **log out and back in once** so GNOME Shell loads the Quake Terminal extension from `~/.local/share/gnome-shell/extensions`. Then F12 drops Alacritty.

`programs.bash.enable` is on, so `~/.bashrc` is Home Manager-owned (the previous file is `~/.bashrc.backup`). Starship, pay-respects (`fuck`), ble.sh, Atuin, `cat` → bat, and `ls` → eza are declared there — a clean `./setup.sh` gets the same shell. Extra host-only lines (pyenv, …) go in `programs.bash.initExtra` in `home.local.nix`. Warp does not install Atuin or ble.sh.

Home Manager replaces the GNOME `custom-keybindings` array. List any other shortcut paths in `terminal.gnomeExtraCustomKeybindings`. Dash favorites are edited in place (`terminal.pinToGnomeDash`), not replaced.

## Cursor

[Cursor](https://cursor.com/) is installed from nixpkgs (`code-cursor`) via Home Manager — no website AppImage. The FHS/bwrap variant is avoided (Ubuntu 24.04 rejects unprivileged uid maps). The launcher always passes `--no-sandbox` (the store `chrome-sandbox` cannot be root-owned 4755). Nix Mesa and `--ozone-platform=x11` are added only when `systemd-detect-virt` reports `vmware`. Common editor extensions are linked into `~/.cursor/extensions` (devenv, Nix IDE, EditorConfig, Error Lens, direnv, Even Better TOML, YAML, Code Spell Checker, Prettier, GitLens, Material Icon Theme, Path Intellisense).

Language packs are **not** user-global. devenv generates `.vscode/extensions.json` from `languages.*` (`files.".vscode/extensions.json"`; gitignored). `devenv shell` also runs `cursor-sync-extensions` to install missing matching extensions and refresh formatter settings.

| `languages.*` | Extensions |
| --- | --- |
| `rust` | rust-analyzer, CodeLLDB, Dependi |
| `go` | official Go |
| `python` | Python, Pylance, debugpy, Ruff |
| `javascript` or `typescript` | ESLint, Tailwind, pretty-ts-errors, auto-rename-tag (React/Next) |

This devenv leaves those languages off. Enable them in `devenv.local.nix` (or another project's `devenv.nix`) when you need the compiler and the plugins.

`.vscode/settings.json` always points Nix IDE at `devenv lsp` ([nixd](https://github.com/nix-community/nixd)). Cursor user settings are left alone (`programs.cursor` would replace them).

Set `cursor.enable = false;` in `home.local.nix` to skip the editor install.

## Tests

[BATS](https://bats-core.readthedocs.io/) tests live in `tests/`:

```bash
bats -r tests           # full suite
bats tests/setup        # setup.sh only
bats tests/home         # terminal-lib.nix only
```

`setup.bats` sources `setup.sh` (a `main` guard keeps it inert) and redirects host paths through `SETUP_*` variables. `tests/home` only `nix-instantiate`s `home/terminal-lib.nix`; it does not run `home-manager switch` or touch `$HOME`. `tests/copier.bats` copies this template into a throwaway directory and checks `copier update`; it is excluded from generated monorepos. `tests/toolchain-latest.bats` checks max-version alignment without calling endoflife.date.

## Tag guard

Git has no `pre-tag` hook, but `reference-transaction` runs for every ref update and aborts the transaction when it exits non-zero. `hooks/reference-transaction` uses that to run the test suite whenever a tag is created or force-moved:

```console
$ git tag v1.0.0
→ running the setup.sh test suite before creating tag v1.0.0
✗ tests failed; refusing to create tag v1.0.0
fatal: in 'prepared' phase, update aborted by the reference-transaction hook
```

`enterShell` copies the hook into `.git/hooks/` on every shell entry, so entering the environment once installs it. Deleting a tag and fetching tags from a remote are not gated. `DEVENV_SKIP_TAG_TESTS=1 git tag ...` bypasses the check, and the hook is a no-op when `CI` or `GITHUB_ACTIONS` is set so semantic-release can tag from GitHub Actions.

`prek` handles the `pre-commit` and `commit-msg` hooks in `modules/git-hooks.nix` and leaves `reference-transaction` alone, so the two coexist.

Always-on hooks: Nix format/lint (`nixfmt`, `statix`, `deadnix`), `shellcheck`, `typos`, `proselint` (Markdown/RST/txt), `lychee` (dead links in Markdown/HTML), `actionlint`, `yamlfmt`, `check-json`, `trim-trailing-whitespace`, `end-of-file-fixer`, `check-added-large-files`, `check-case-conflicts`, `check-merge-conflicts` (Copier/git conflict markers), `gitleaks` (secrets), and `commitlint` on `commit-msg`.

Language hooks turn on with `languages.*`:

| `languages.*` | Hooks |
| --- | --- |
| `rust` | `rustfmt`, `clippy` |
| `go` | `gofmt`, `golangci-lint` |
| `python` | `ruff`, `ruff-format`, `check-python`, `python-debug-statements`, `sort-requirements-txt`, plus `pyright` (default) or `ty` via `pythonTypeChecker` |
| `javascript` or `typescript` | `prettier` (JS/TS files only) |
| any of `rust`, `python`, `javascript`, `typescript`, `go` | `debtmap` (reads generated `.debtmap.toml`) |

`devenv shell` writes `.debtmap.toml` (gitignored) from `languages.*` and `debtmap.*`. Thresholds, ignore globs, and per-language god-object limits default to the [upstream example](https://github.com/iepathos/debtmap/blob/master/.debtmap.toml). Override them in `devenv.local.nix`; do not edit the generated file.

## Conventional Commits

Commit messages must follow [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, `ci:`, `test:`, `chore:`, …). The `commitlint` **commit-msg** hook (not pre-commit) rejects other subjects. On push to `master` or `main`, CI runs [semantic-release](https://semantic-release.gitbook.io/semantic-release/) to version, tag, and publish a GitHub Release from those commits. Those tags are what `copier copy` and `copier update` use by default.

## CI

| Workflow | Trigger | Runs |
| --- | --- | --- |
| `ci.yml` | Push and pull request to `main`/`master` | `test-devenv` on Ubuntu 22.04 (publishes `junit/*.xml` as a PR check and annotations); then `test.yml` if it exists; on push to `master`/`main` only, `semantic-release` |
| `test.yml` | Called from `ci.yml` after `test-devenv` | Per-language `devenv test` for each supported version (generated reusable workflow; Ubuntu 22.04; no cross-language matrix) |
| `setup-tests.yml` | Changes to `setup.sh`, `tests/setup/`, `tests/tag-hook.bats`, or `hooks/`, and every tag push | `bats tests/setup tests/tag-hook.bats` on Ubuntu 22.04 |

`setup-tests.yml` has no branch or tag filter, which makes it run for branch pushes matching its paths and for all tag pushes — GitHub skips path filters on tag pushes.

`test-devenv` writes JUnit reports under `junit/` (gitignored): `nix-unit.xml`, `bats.xml`, and `nixos-test.xml`. Each failing case includes a repo-relative `file` and `line` so GitHub can annotate the pull request. `nix-unit` has no native JUnit flag; `tests/junit-report.py` parses its output and maps test names back to `tests/unit/*.nix`. The nixosTest derivation itself discards the driver's XML (`LOGFILE=/dev/null`), so the report is one case pointing at `tests/integration/default.nix`. CI uploads those files and runs [publish-unit-test-result-action](https://github.com/EnricoMi/publish-unit-test-result-action).

`test-devenv` also `actionlint`s `.github/workflows/test.yml` and fixtures from `tests/integration/workflows.nix` (empty, Python 3.12–3.13, Rust, Go, Deno). It then runs `act workflow_call` on the repo `test.yml` (local only; CI already calls that file) and on the Python fixture so the generated `strategy.matrix.include` jobs actually execute. Skip nested `act` when `ACT` is set.

`.actrc` maps `ubuntu-22.04` to `devenv-act:22.04` and runs the container as `runner`. Build that image first (`build-act-image`, or `test-devenv` does it). Local act keeps `/nix` and `~/.cache/nix` in Docker volumes `devenv-act-nix` and `devenv-act-nix-cache`. GitHub Actions uses [cache-nix-action](https://github.com/nix-community/cache-nix-action) (skipped under act; the cache API is not available). Do not run bare `act` / `act pull_request` against `ci.yml` unless you want a full CI replay.
