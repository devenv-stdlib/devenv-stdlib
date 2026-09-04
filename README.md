# devenv

Portable [devenv](https://devenv.sh/) configuration for a reproducible Linux development toolchain.

Clone this repository on any Linux machine, install Nix and devenv, then enter the shell. Packages, git hooks, and tests are pinned in `devenv.lock`.

## Prerequisites

- Linux (x86_64 or aarch64)
- `curl` and a user that can create `/nix` (the Nix installer typically needs `sudo` once)

## Bootstrap on a fresh machine

### 1. Install Nix

```bash
curl -sSfL https://artifacts.nixos.org/nix-installer | sh -s -- install
```

Open a new shell so `nix` is on `PATH`, or source the profile the installer prints.

Enable flakes if they are not already on (the installer usually does this):

```bash
mkdir -p ~/.config/nix
cat >> ~/.config/nix/nix.conf <<'EOF'
experimental-features = nix-command flakes
extra-substituters = https://devenv.cachix.org
extra-trusted-public-keys = devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=
EOF
```

### 2. Install devenv

```bash
nix profile install nixpkgs#devenv
```

### 3. Clone and enter the environment

```bash
git clone <this-repo-url> ~/Projects/devenv
cd ~/Projects/devenv
devenv allow          # trust this directory for devenv's shell hook
# or, with direnv: direnv allow
devenv shell
```

You should see `devenv ready: <user>@<hostname>`. After that, `git`, `gh`, `jq`, `rg`, `fd`, `direnv`, and `nixfmt` are on `PATH`.

## Everyday commands

| Command | Purpose |
| --- | --- |
| `devenv shell` | Enter the environment |
| `devenv test` | Build the env and run `enterTest` |
| `devenv update` | Refresh `devenv.lock` from `devenv.yaml` inputs |
| `devenv gc` | Delete unused environment generations |

Optional auto-activation:

- **devenv hook** (no extra tools): add `eval "$(devenv hook bash)"` to `~/.bashrc`, then `devenv allow` in this repo.
- **direnv**: install direnv, hook it in your shell, then `direnv allow` here (`.envrc` is committed).

## Layout

| Path | Role |
| --- | --- |
| `devenv.nix` | Shell banner, Cachix pull, tests |
| `devenv.yaml` | Inputs, module imports, CLI version pin |
| `devenv.lock` | Pinned inputs (commit this) |
| `modules/packages.nix` | Shared CLI packages |
| `modules/git-hooks.nix` | `nixfmt-rfc-style`, `statix`, `deadnix` |
| `modules/languages.nix` | Commented language examples (off by default) |
| `devenv.local.nix` | Gitignored machine-specific overrides |

## Local overrides

Copy options you do not want to share into `devenv.local.nix`:

```nix
{ ... }:
{
  # packages = [ pkgs.hello ];
}
```

## CI

GitHub Actions installs Nix and devenv, then runs `devenv test` on every push and pull request to `main`/`master`.
