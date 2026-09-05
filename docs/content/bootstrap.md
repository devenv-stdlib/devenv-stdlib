# Bootstrap

One command configures the devenv binary cache as root, applies `home.nix` (Alacritty + Zellij + Quake Terminal, Atuin + ble.sh, Cursor + devenv extension, Starship), and builds this environment:

```bash
./setup.sh
```

The script prints a notice that it needs `sudo` for the Nix daemon, flakes (if missing), and `cachix use devenv`. It does **not** add your user to Nix `trusted-users`. Home Manager is installed into the user Nix profile and does not need sudo.

Then enter the project toolchain:

```bash
devenv shell
```

The shell banner uses the Copier `name` (this template prints `devenv4monorepo ready: <user>@<hostname>`). After that, `git`, `gh`, `jq`, `rg`, `fd`, `direnv`, `nixfmt`, `bats`, `shellcheck`, `home-manager`, `copier`, and `debtmap` are on `PATH`.

## Re-apply Home Manager

```bash
home-switch
```

That is `home-manager switch -b backup -f home.nix`. Existing files Home Manager needs to replace are moved aside with a `.backup` suffix. On flakes-only hosts, `home-switch` and `setup.sh` set `NIX_PATH=nixpkgs=flake:nixpkgs` when `NIX_PATH` has no `nixpkgs=` entry.

## Everyday commands

| Command | Purpose |
| --- | --- |
| `./setup.sh` | Install or update Nix, devenv, Cachix, and Home Manager |
| `copier copy <src> <dest>` | Apply this template to a monorepo |
| `copier update` | Pull a newer tagged template into an existing copy |
| `copier check-update` | Report whether a newer template tag exists |
| `devenv shell` | Enter the project toolchain |
| `home-switch` | Re-apply Home Manager after editing `home.nix` |
| `devenv test` | Build the env, check the toolchain, and run BATS |

Optional auto-activation:

- **devenv hook** (no extra tools): add `eval "$(devenv hook bash)"` to `~/.bashrc.d/99-devenv-hook.sh` or `programs.bash.initExtra` in `home.local.nix`, then `devenv allow` in this repo.
- **direnv**: Home Manager installs direnv + nix-direnv and hooks bash. `direnv allow` here (`.envrc` is committed).
