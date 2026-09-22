# Bootstrap

One command configures the devenv binary cache as root, applies `home.nix` (Alacritty + Zellij + Quake Terminal, Atuin + ble.sh, Cursor + devenv extension, Starship), and builds this environment:

```bash
./setup.sh
```

The script prints a notice that it needs `sudo` for the Nix daemon, flakes (if missing), `cachix use devenv`, and (on AppArmor hosts) Cursor Agent terminal sandbox profiles. It does **not** add your user to Nix `trusted-users`. Home Manager is installed into the user Nix profile and does not need sudo. It does **not** install Docker. This stack defaults to **rootless Docker** (`DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock`) for local `act` and the Docker MCP. `devenv shell` and `~/.bashrc.d/20-docker-rootless.sh` set that unless `CI` / `GITHUB_ACTIONS` is set (GitHub-hosted runners stay on the rootful daemon). If the user socket is missing after setup:

```bash
dockerd-rootless-setuptool.sh install
systemctl --user enable --now docker
loginctl enable-linger "$USER"
```

Override with `DOCKER_HOST=unix:///var/run/docker.sock` or `docker.rootless.enable = false;` in `home.local.nix`.

Then enter the project toolchain:

```bash
devenv shell
```

The shell banner uses the Copier `name` (this template prints `devenv4monorepo ready: <user>@<hostname>`). After that, `git`, `gh`, `jq`, `rg`, `fd`, `direnv`, `nixfmt`, `bats`, `shellcheck`, `home-manager`, `copier`, and `debtmap` are on `PATH`. `setup.sh` and every `devenv shell` entry set this repository's local git config `rerere.enabled` and `rerere.autoupdate` to `true` (remember and auto-stage recorded conflict resolutions).

## Re-apply Home Manager

```bash
home-switch
```

That is `home-manager switch -b backup -f home.nix`. `home-switch` loads secrets with `secretspec export` (whatever provider is configured: dotenv, keyring, env, …) and falls back to sourcing gitignored `.env` if export is unavailable. Activation then sees `BRAVE_API_KEY` / `FIRECRAWL_API_KEY`. Existing files Home Manager needs to replace are moved aside with a `.backup` suffix. On flakes-only hosts, `home-switch` and `setup.sh` set `NIX_PATH=nixpkgs=flake:nixpkgs` when `NIX_PATH` has no `nixpkgs=` entry, and drop search-path directories that do not exist (such as `~/.nix-defexpr/channels` without channels), which Nix would otherwise warn about on every evaluation.

## Everyday commands

| Command | Purpose |
| --- | --- |
| `./setup.sh` | Install or update Nix, devenv, Cachix, and Home Manager |
| `copier copy <src> <dest>` | Apply this template to a monorepo |
| `copier update` | Pull a newer tagged template into an existing copy (Serena, Headroom, MCP pins, debtmap, agent skills, …) |
| `copier check-update` | Report whether a newer template tag exists |
| `update` | Our devenv script (`devenv run update`): in a generated repo, `devenv update`, then `catalog.local.toml` (Nix or mise), then `update.local.sh`; in this template, refresh shipped non-Nix pins. Not the devenv CLI. |
| `non-nix:add-local` / `non-nix:remove-local` | Add or remove a team tool in `modules/non-nix/catalog.local.toml` (creates the file from root `catalog.local.toml.example` if missing). Example: `devenv tasks run non-nix:add-local -- --name example-cli --kind cli --scope project --pin 1.0.0 --mise ubi:owner/example-cli --docs 'Example CLI. Docs: https://example.com'`. |
| `devenv update` | devenv CLI: flake inputs in `devenv.lock` only (`nixpkgs`, `git-hooks`, …) |
| `devenv shell` | Enter the project toolchain |
| `home-switch` | Re-apply Home Manager after editing `home.nix` |
| `navi` | Browse repo `cheats/` plus community [denisidoro/cheats](https://github.com/denisidoro/cheats) |
| `devenv test` | Build the env, check the toolchain, and run BATS |

Optional auto-activation:

- **devenv hook** (no extra tools): add `eval "$(devenv hook bash)"` to `~/.bashrc.d/99-devenv-hook.sh` or `programs.bash.initExtra` in `home.local.nix`, then `devenv allow` in this repo.
- **direnv**: Home Manager installs direnv + nix-direnv and hooks bash. `direnv allow` here (`.envrc` is committed).
