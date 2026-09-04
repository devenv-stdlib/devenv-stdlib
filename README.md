# devenv

Portable [devenv](https://devenv.sh/) configuration for a reproducible Linux project toolchain, plus a [Home Manager](https://nix-community.github.io/home-manager/) module for a user-global dropdown terminal and Starship.

Clone this repository and run `./setup.sh`. That one command installs or updates Nix, devenv, Cachix, and Home Manager, then applies `home.nix` and builds the devenv shell. The dropdown terminal is **not** part of the devenv PATH: you already have a terminal open to enter it.

## Prerequisites

- Linux (x86_64 or aarch64)
- `curl` and a user that can create `/nix` (the Nix installer typically needs `sudo` once)

## Bootstrap on a fresh machine

From the repository root, one command installs or updates Nix, devenv, Cachix, and Home Manager, configures the devenv binary cache as root, applies `home.nix` (Alacritty + Zellij + Quake Terminal, Atuin + ble.sh, Cursor + devenv extension, Starship), and builds this environment:

```bash
./setup.sh
```

The script prints a notice that it needs `sudo` for the Nix daemon, flakes (if missing), and `cachix use devenv`. It does **not** add your user to Nix `trusted-users`. Home Manager is installed into the user Nix profile and does not need sudo.

Then enter the project toolchain:

```bash
devenv shell
```

You should see `devenv ready: <user>@<hostname>`. After that, `git`, `gh`, `jq`, `rg`, `fd`, `direnv`, `nixfmt`, `bats`, `shellcheck`, and `home-manager` are on `PATH`.

Re-apply the user-global terminal after editing `home.nix` (also done by `./setup.sh`):

```bash
home-switch
```

That is `home-manager switch -b backup -f home.nix`. Existing files Home Manager needs to replace are moved aside with a `.backup` suffix. On flakes-only hosts, `home-switch` and `setup.sh` set `NIX_PATH=nixpkgs=flake:nixpkgs` when `NIX_PATH` has no `nixpkgs=` entry.

## Everyday commands

| Command | Purpose |
| --- | --- |
| `./setup.sh` | Install or update Nix, devenv, Cachix, and Home Manager; apply `home.nix`; build this environment |
| `devenv shell` | Enter the project toolchain |
| `home-switch` | Re-apply Home Manager after editing `home.nix` (same as the setup.sh HM step) |
| `devenv test` | Build the env, check the toolchain, and run the BATS suite |
| `bats -r tests` | Run the full BATS suite (setup, home/terminal-lib, tag hook) |
| `devenv update` | Refresh `devenv.lock` from `devenv.yaml` inputs |
| `devenv gc` | Delete unused environment generations |

Optional auto-activation:

- **devenv hook** (no extra tools): add `eval "$(devenv hook bash)"` to `~/.bashrc`, then `devenv allow` in this repo.
- **direnv**: install direnv, hook it in your shell, then `direnv allow` here (`.envrc` is committed).

## Layout

| Path | Role |
| --- | --- |
| `setup.sh` | One-command host bootstrap (Nix, devenv, Cachix, Home Manager, this environment) |
| `devenv.nix` | Shell banner, Cachix pull, tests, `home-switch` |
| `devenv.yaml` | Inputs, module imports, CLI version pin |
| `devenv.lock` | Pinned inputs (commit this) |
| `home.nix` | Home Manager entry (username from `$USER` / `$HOME`) |
| `home/terminal.nix` | Shared options: `terminal.provider` (default `alacritty`), F12, dash pin |
| `home/alacritty.nix` | Alacritty, Zellij, Quake Terminal, Atuin (daemon-fuzzy), ble.sh |
| `home/cursor.nix` | Cursor IDE and the devenv VS Code extension |
| `home/warp.nix` | Optional Warp provider (VMware-hostile; opt in) |
| `home/terminal-lib.nix` | Keybinding map, desktop entries, Warp settings.toml |
| `home.local.nix.example` | Template for gitignored `home.local.nix` |
| `modules/packages.nix` | Project CLI packages (includes `home-manager`) |
| `modules/git-hooks.nix` | `nixfmt-rfc-style`, `statix`, `deadnix`, `shellcheck` |
| `modules/languages.nix` | Commented language examples (off by default) |
| `tests/setup/setup.bats` | Unit tests for `setup.sh` |
| `tests/home/terminal-lib.bats` | Eval tests for `home/terminal-lib.nix` |
| `tests/tag-hook.bats` | Tests that a failing suite really blocks `git tag` |
| `hooks/reference-transaction` | Tag guard, installed into `.git/hooks` on shell entry |
| `devenv.local.nix` | Gitignored devenv overrides |
| `home.local.nix` | Gitignored Home Manager overrides |

## Local overrides

Copy devenv-only options into `devenv.local.nix`:

```nix
{ ... }:
{
  # packages = [ pkgs.hello ];
}
```

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

`programs.bash.enable` is on, so `~/.bashrc` is Home Manager-owned (the previous file is `~/.bashrc.backup`). Starship, ble.sh, and Atuin are declared there — a clean `./setup.sh` gets the same shell. Extra host-only lines (pyenv, …) go in `programs.bash.initExtra` in `home.local.nix`. Warp does not install Atuin or ble.sh.

Home Manager replaces the GNOME `custom-keybindings` array. List any other shortcut paths in `terminal.gnomeExtraCustomKeybindings`. Dash favorites are edited in place (`terminal.pinToGnomeDash`), not replaced.

## Cursor

[Cursor](https://cursor.com/) is installed from nixpkgs (`code-cursor`) via Home Manager — no website AppImage. The FHS/bwrap variant is avoided (Ubuntu 24.04 rejects unprivileged uid maps). The launcher always passes `--no-sandbox` (the store `chrome-sandbox` cannot be root-owned 4755). Nix Mesa and `--ozone-platform=x11` are added only when `systemd-detect-virt` reports `vmware`. Extensions are linked into `~/.cursor/extensions`:

- [devenv](https://marketplace.visualstudio.com/items?itemName=datakurre.devenv) — loads `devenv print-dev-env` into the editor
- [Nix IDE](https://marketplace.visualstudio.com/items?itemName=jnoortheen.nix-ide) — syntax and LSP

`.vscode/settings.json` points Nix IDE at `devenv lsp`, which starts a bundled [nixd](https://github.com/nix-community/nixd) already configured for this `devenv.nix`. Cursor user settings are left alone (`programs.cursor` would replace them).

Set `cursor.enable = false;` in `home.local.nix` to skip the editor install.

## Tests

[BATS](https://bats-core.readthedocs.io/) tests live in `tests/`:

```bash
bats -r tests           # full suite
bats tests/setup        # setup.sh only
bats tests/home         # terminal-lib.nix only
```

`setup.bats` sources `setup.sh` (a `main` guard keeps it inert) and redirects host paths through `SETUP_*` variables. `tests/home` only `nix-instantiate`s `home/terminal-lib.nix`; it does not run `home-manager switch` or touch `$HOME`.

## Tag guard

Git has no `pre-tag` hook, but `reference-transaction` runs for every ref update and aborts the transaction when it exits non-zero. `hooks/reference-transaction` uses that to run the test suite whenever a tag is created or force-moved:

```console
$ git tag v1.0.0
→ running the setup.sh test suite before creating tag v1.0.0
✗ tests failed; refusing to create tag v1.0.0
fatal: in 'prepared' phase, update aborted by the reference-transaction hook
```

`enterShell` copies the hook into `.git/hooks/` on every shell entry, so entering the environment once installs it. Deleting a tag and fetching tags from a remote are not gated, and `DEVENV_SKIP_TAG_TESTS=1 git tag ...` bypasses the check.

`prek` handles the `pre-commit` hooks in `modules/git-hooks.nix` and leaves `reference-transaction` alone, so the two coexist.

## CI

| Workflow | Trigger | Runs |
| --- | --- | --- |
| `ci.yml` | Push and pull request to `main`/`master` | `devenv test` |
| `setup-tests.yml` | Changes to `setup.sh`, `tests/setup/`, `tests/tag-hook.bats`, or `hooks/`, and every tag push | `bats tests/setup tests/tag-hook.bats` |

`setup-tests.yml` has no branch or tag filter, which makes it run for branch pushes matching its paths and for all tag pushes — GitHub skips path filters on tag pushes.
