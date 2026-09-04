# devenv

Portable [devenv](https://devenv.sh/) configuration for a reproducible Linux development toolchain.

Clone this repository, run `./setup.sh`, then `devenv shell`. Packages, git hooks, and tests are pinned in `devenv.lock`.

## Prerequisites

- Linux (x86_64 or aarch64)
- `curl` and a user that can create `/nix` (the Nix installer typically needs `sudo` once)

## Bootstrap on a fresh machine

From the repository root, one command installs or updates Nix, devenv, and Cachix, configures the devenv binary cache as root, and builds this environment:

```bash
./setup.sh
```

The script prints a notice that it needs `sudo` for the Nix daemon, flakes (if missing), and `cachix use devenv`. It does **not** add your user to Nix `trusted-users`.

Then enter the environment:

```bash
devenv shell
```

You should see `devenv ready: <user>@<hostname>`. After that, `git`, `gh`, `jq`, `rg`, `fd`, `direnv`, `nixfmt`, `bats`, `shellcheck`, `starship`, and `warp-terminal` are on `PATH`.

## Everyday commands

| Command | Purpose |
| --- | --- |
| `./setup.sh` | Install or update Nix, devenv, and Cachix; build this environment |
| `devenv shell` | Enter the environment |
| `devenv test` | Build the env, check the toolchain, and run the BATS suite |
| `bats tests` | Run the `setup.sh` test suite on its own |
| `devenv update` | Refresh `devenv.lock` from `devenv.yaml` inputs |
| `devenv gc` | Delete unused environment generations |

Optional auto-activation:

- **devenv hook** (no extra tools): add `eval "$(devenv hook bash)"` to `~/.bashrc`, then `devenv allow` in this repo.
- **direnv**: install direnv, hook it in your shell, then `direnv allow` here (`.envrc` is committed).

## Layout

| Path | Role |
| --- | --- |
| `setup.sh` | One-command host bootstrap (Nix, devenv, Cachix, this environment) |
| `devenv.nix` | Shell banner, Cachix pull, tests |
| `devenv.yaml` | Inputs, module imports, CLI version pin |
| `devenv.lock` | Pinned inputs (commit this) |
| `modules/packages.nix` | Shared CLI packages |
| `modules/git-hooks.nix` | `nixfmt-rfc-style`, `statix`, `deadnix`, `shellcheck` |
| `modules/languages.nix` | Commented language examples (off by default) |
| `tests/setup.bats` | Unit tests for `setup.sh` |
| `tests/tag-hook.bats` | Tests that a failing suite really blocks `git tag` |
| `tests/warp.bats` | Unit tests for `scripts/apply-warp.sh` |
| `hooks/reference-transaction` | Tag guard, installed into `.git/hooks` on shell entry |
| `modules/warp.nix` | Warp + Starship; Quake keybinding defaults to F12 |
| `scripts/apply-warp.sh` | Writes Warp settings, a Wayland launcher, and the GNOME F12 shortcut |
| `devenv.local.nix` | Gitignored machine-specific overrides |

## Local overrides

Copy options you do not want to share into `devenv.local.nix`:

```nix
{ ... }:
{
  # packages = [ pkgs.hello ];
  # warp.quakeKeybinding = "ctrl-`";
}
```

## Warp and Starship

Entering the environment installs [Warp](https://www.warp.dev/) (with `WARP_ENABLE_WAYLAND=1`) and [Starship](https://starship.rs/), then applies the equivalent of Warp's Settings UI:

| Setting | Value |
| --- | --- |
| Features → System → native Wayland | on (`WARP_ENABLE_WAYLAND=1` and `force_x11 = false`) |
| Features → Keys → dedicated hotkey window (Quake) | on, pinned to the top edge |
| Quake keybinding | `f12` (override with `warp.quakeKeybinding`) |
| Features → Session → Honor user's custom prompt | on (`honor_ps1 = true`) |

Warp cannot register its own global hotkey on Wayland, so `apply-warp.sh` also binds the same shortcut as a GNOME custom shortcut that launches `~/.local/bin/warp-terminal`. A second launch focuses the existing window.

Change the shortcut from `devenv.local.nix` without editing the shared module:

```nix
{ ... }:
{
  warp.quakeKeybinding = "ctrl-`";
}
```

`enterShell` writes `~/.config/warp-terminal/settings.toml` (other keys you add are kept), installs a desktop entry, and appends `eval "$(starship init bash)"` to `~/.bashrc` if it is not already there.

## Tests

The shell scripts are covered by [BATS](https://bats-core.readthedocs.io/) tests in `tests/`:

```bash
bats tests
```

Both suites source the script under test (a `main` guard keeps it inert when sourced) and redirect every host path through environment variables, so they never touch the real `/nix`, the network, `sudo`, `~/.config`, or your GNOME settings. `setup.bats` uses the `SETUP_*` variables; `warp.bats` uses the `WARP_*` variables plus a recording `gsettings` stub.

## Tag guard

Git has no `pre-tag` hook, but `reference-transaction` runs for every ref update and aborts the transaction when it exits non-zero. `hooks/reference-transaction` uses that to run the test suite whenever a tag is created or force-moved, so a broken `setup.sh` cannot be tagged:

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
| `setup-tests.yml` | Changes to `setup.sh`, `tests/`, or `hooks/`, and every tag push | `bats tests` |
| `scripts-tests.yml` | Changes under `scripts/`, and every tag push | `shellcheck scripts/*.sh` and `bats tests/warp.bats` |

Neither test workflow defines a branch or tag filter, which makes each run for branch pushes matching its paths and for all tag pushes — GitHub skips path filters on tag pushes.
