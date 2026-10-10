# devenv4monorepo

Published **devenv-stdlib** package: a [devenv](https://devenv.sh/) project toolchain that matches CI, plus a [Home Manager](https://nix-community.github.io/home-manager/) desktop (dropdown terminal, Starship, Cursor) that is **not** trapped inside `devenv shell`.

Pin the flake in your monorepo. Compose presets and tools against that revision. Stop pasting `devenv.nix` between trees and hoping the laptops still agree.

**[Documentation](https://devenv4monorepo.github.io/)** · **[Contribution guide](https://devenv4monorepo.github.io/#contributing)**

## Why not rustup + nvm + a wiki page?

A monorepo is several languages and several products in one git history. Per-laptop installers drift. A GUI terminal is not a project dependency — you already have a window open to enter the shell. This package keeps those lifetimes apart:

- **devenv** — compilers, hooks, and a generated version matrix for *this* tree
- **Home Manager** — Alacritty + Zellij (F12), Cursor, and the CLIs you want everywhere
- **Flake pin** — one `devenv-stdlib` revision so frameworks, presets, and tools move together

Ubuntu 26.04 LTS and 24.04 LTS (x86_64 or aarch64) are the supported hosts.

## Use in a monorepo

```nix
# flake.nix — see consumer-flake.nix.example
inputs.devenv-stdlib.url = "github:devenv-stdlib/devenv-stdlib/<tag-or-sha>";
```

Import `${inputs.devenv-stdlib}/packaging/den-outputs.nix`, load `"${inputs.devenv-stdlib}/presets"` plus local `./presets`, and enable languages in your own `devenv.local.nix`.

Full walkthrough: [Consume](https://devenv4monorepo.github.io/#apply) · [Bootstrap](https://devenv4monorepo.github.io/#bootstrap) · [Architecture](https://devenv4monorepo.github.io/#architecture) · [Tools](https://devenv4monorepo.github.io/#tools)
