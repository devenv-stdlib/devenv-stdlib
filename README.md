# devenv

Portable [devenv](https://devenv.sh/) configuration for a reproducible Linux project toolchain, plus a [Home Manager](https://nix-community.github.io/home-manager/) module for user-global Warp, Starship, and GNOME settings.

Clone this repository and run `./setup.sh`. That one command installs or updates Nix, devenv, Cachix, and Home Manager, then applies this repo's user-global Warp/Starship/GNOME config and builds the devenv shell. Warp is **not** part of the devenv PATH: you already have a terminal open to enter it.

## Prerequisites

- Linux (x86_64 or aarch64)
- `curl` and a user that can create `/nix` (the Nix installer typically needs `sudo` once)

## Bootstrap on a fresh machine

From the repository root, one command installs or updates Nix, devenv, Cachix, and Home Manager, configures the devenv binary cache as root, applies `home.nix` (Warp, Starship, Quake shortcut), and builds this environment:

```bash
./setup.sh
```

The script prints a notice that it needs `sudo` for the Nix daemon, flakes (if missing), and `cachix use devenv`. It does **not** add your user to Nix `trusted-users`. Home Manager is installed into the user Nix profile and does not need sudo.

Then enter the project toolchain:

```bash
devenv shell
```

You should see `devenv ready: <user>@<hostname>`. After that, `git`, `gh`, `jq`, `rg`, `fd`, `direnv`, `nixfmt`, `bats`, `shellcheck`, and `home-manager` are on `PATH`.

Re-apply user-global Warp/Starship/GNOME config after editing `home.nix` (also done by `./setup.sh`):

```bash
home-switch
```

That is `home-manager switch -b backup -f home.nix`. Existing files Home Manager needs to replace are moved aside with a `.backup` suffix.

## Everyday commands

| Command | Purpose |
| --- | --- |
| `./setup.sh` | Install or update Nix, devenv, Cachix, and Home Manager; apply `home.nix`; build this environment |
| `devenv shell` | Enter the project toolchain |
| `home-switch` | Re-apply Home Manager after editing `home.nix` (same as the setup.sh HM step) |
| `devenv test` | Build the env, check the toolchain, and run the BATS suite |
| `bats -r tests` | Run the full BATS suite (setup, home/warp-lib, tag hook) |
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
| `home/warp.nix` | Warp, Starship, Quake settings, desktop entry, GNOME shortcut |
| `home/warp-lib.nix` | Shared package override, settings.toml, keybinding map |
| `home.local.nix.example` | Template for gitignored `home.local.nix` |
| `modules/packages.nix` | Project CLI packages (includes `home-manager`) |
| `modules/git-hooks.nix` | `nixfmt-rfc-style`, `statix`, `deadnix`, `shellcheck` |
| `modules/languages.nix` | Commented language examples (off by default) |
| `tests/setup/setup.bats` | Unit tests for `setup.sh` |
| `tests/home/warp-lib.bats` | Eval tests for `home/warp-lib.nix` |
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
  warp.quakeKeybinding = "ctrl-`";
}
```

`warp.quakeKeybinding` used to live in `devenv.local.nix`; move it if you still have that line.

## Warp and Starship

[Warp](https://www.warp.dev/) and [Starship](https://starship.rs/) are user-global, installed by Home Manager, not by `devenv shell`. `home-switch` applies the equivalent of Warp's Settings UI and a GNOME launcher:

| Setting | Value |
| --- | --- |
| Features → System → native Wayland | on (`WARP_ENABLE_WAYLAND=1` and `force_x11 = false`) |
| Features → Keys → dedicated hotkey window (Quake) | on, pinned to the top edge |
| Quake keybinding | `f12` (override with `warp.quakeKeybinding` in `home.local.nix`) |
| Features → Session → Honor user's custom prompt | on (`honor_ps1 = true`) |

Warp cannot register its own global hotkey on Wayland, so Home Manager also binds the same shortcut as a GNOME custom shortcut that launches the Wayland-wrapped `warp-terminal`. A second launch focuses the existing window.

`programs.bash` is **not** enabled, so Home Manager does not replace `~/.bashrc`. Keep this line there (already present on this machine):

```bash
eval "$(starship init bash)"
```

`programs.starship.enable` installs Starship into the user profile; `enableBashIntegration` stays off so init is not duplicated.

`~/.config/warp-terminal/settings.toml` is Home Manager-owned (nix store symlink). Put extra TOML in `warp.extraSettings` instead of the Warp UI if you need it to persist. Home Manager replaces the GNOME `custom-keybindings` array; list any other shortcut paths in `warp.gnomeExtraCustomKeybindings`.

Host leftovers from the old `apply-warp.sh` path (safe to remove after a successful `home-switch`): `~/.local/bin/warp-terminal`. Keep the Starship line in `~/.bashrc`. The previous GNOME shortcut and desktop entry are replaced by Home Manager.

## Tests

[BATS](https://bats-core.readthedocs.io/) tests live in `tests/`:

```bash
bats -r tests           # full suite
bats tests/setup        # setup.sh only
bats tests/home         # warp-lib.nix only
```

`setup.bats` sources `setup.sh` (a `main` guard keeps it inert) and redirects host paths through `SETUP_*` variables. `tests/home` only `nix-instantiate`s `home/warp-lib.nix`; it does not run `home-manager switch` or touch `$HOME`.

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
