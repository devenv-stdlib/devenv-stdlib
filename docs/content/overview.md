# Overview

This repository is a [Copier](https://copier.readthedocs.io/en/stable) template for a Linux monorepo: a [devenv](https://devenv.sh/) project toolchain plus a [Home Manager](https://nix-community.github.io/home-manager/) module for the user-global terminal, Starship, and Cursor.

A monorepo copies the template once, then runs `copier update` when a new tagged release ships. Clone this repo only to develop the template itself; see the [Contribution guide](#contributing).

The dropdown terminal is **not** part of the devenv PATH: you already have a terminal open to enter it.

## Why this template

A monorepo is several products and languages in one git tree. The usual laptop setup fights that:

- Each language has its own installer (`rustup`, `pyenv`, `nvm`, Homebrew). Two clones on one machine silently drift.
- A GUI terminal and editor are not a project dependency. Putting them on the devenv PATH couples “open a window” to “enter this repo.”
- Copy-pasting a `devenv.nix` between repos means the next policy change (hooks, CI, Rust edition) never reaches the others.

This template splits those problems:

| Need | Mechanism |
| --- | --- |
| The same skeleton in every monorepo, updatable later | Copier (`copy` / `update`) |
| Compilers, linters, and hooks for *this* tree | devenv (`devenv.nix` + generated `devenv.local.nix`) |
| Terminal, prompt, and editor on every host | Home Manager (`home.nix`) |
| CI that matches the versions developers can use | `supported.<lang>.*` and a generated `test.yml` |

Languages stay **off** in this template repo so work on the skeleton does not pull Rust, Go, Python, or Node. Generated monorepos turn them on through the Copier questionnaire.

## What you get

- A devenv shell named in the questionnaire (this checkout prints `devenv4monorepo ready: <user>@<hostname>`)
- Home Manager for Alacritty + Zellij + Quake Terminal (or Warp), Atuin, ble.sh, Starship, Cursor, and everyday CLIs
- Copier questions that write `devenv.local.nix` (`name`, `languages.*`, `supported.*`)
- Always-on git hooks, language-gated hooks, Conventional Commits, and semantic-release tags
- Per-language version matrices and generated GitHub Actions

## Supported host

Ubuntu 22.04 LTS (x86_64 or aarch64) is the only OS supported in this MVP. You need `curl` and a user that can create `/nix` (the Nix installer typically needs `sudo` once).
