# Overview

This repository publishes **devenv-stdlib**: a Nix flake package for a Linux monorepo — a [devenv](https://devenv.sh/) project toolchain plus a [Home Manager](https://nix-community.github.io/home-manager/) module for the user-global terminal, Starship, and Cursor.

Consumers pin `github:thedrow/devenv4monorepo/<tag-or-sha>` and compose presets/tools against that revision. Clone this repo to develop or dogfood the package itself; see the [Contribution guide](#contributing).

The dropdown terminal is **not** part of the devenv PATH: you already have a terminal open to enter it.

## Why this package

A monorepo is several products and languages in one git tree. The usual laptop setup fights that:

- Each language has its own installer (`rustup`, `pyenv`, `nvm`, Homebrew). Two clones on one machine silently drift.
- A GUI terminal and editor are not a project dependency. Putting them on the devenv PATH couples “open a window” to “enter this repo.”
- Copy-pasting a `devenv.nix` between repos means the next policy change (hooks, CI, Rust edition) never reaches the others.

This package splits those problems:

| Need | Mechanism |
| --- | --- |
| Shared framework, tools, and presets at a locked revision | Flake input `devenv-stdlib` |
| Compilers, linters, and hooks for *this* tree | devenv (`devenv.nix` + local `devenv.local.nix`) |
| Terminal, prompt, and editor on every host | Home Manager (Den `home-switch`) |
| CI that matches the versions developers can use | `supported.<lang>.*` and a generated `test.yml` |

Languages stay **off** in this publisher checkout so work on the framework does not pull Rust, Go, Python, or Node. Consumer repos turn them on in their own `devenv.local.nix`.

## What you get

- A devenv shell (this checkout prints `devenv4monorepo ready: <user>@<hostname>`)
- Home Manager for Alacritty + Zellij + Quake Terminal (or Warp), Atuin, ble.sh, Starship, Cursor, and everyday CLIs
- Always-on git hooks, language-gated hooks, Conventional Commits, and semantic-release tags
- Per-language version matrices and generated GitHub Actions
- Flake outputs `stdlib` / `lib` plus shippable `presets/` and `packaging/`

## Supported hosts

The supported hosts are the **current Ubuntu LTS and the previous one** (today: 26.04 and 24.04; x86_64 or aarch64). You need `curl`, a user that can create `/nix` (the Nix installer typically needs `sudo` once), and **rootless Docker** for local `act`. `setup.sh` does not install Docker. See [Docker rootless mode](https://docs.docker.com/engine/security/rootless/). Set `DOCKER_HOST=unix:///var/run/docker.sock` only if you must use a rootful daemon.
