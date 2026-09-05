# devenv4monorepo

One Copier template for every Linux monorepo: a [devenv](https://devenv.sh/) toolchain that matches CI, and a [Home Manager](https://nix-community.github.io/home-manager/) desktop (dropdown terminal, Starship, Cursor) that is **not** trapped inside `devenv shell`.

Copy it once. When hooks, version policy, or CI change, `copier update` brings the skeleton forward. You stop pasting `devenv.nix` between trees and hoping the laptops still agree.

**[Documentation](https://devenv4monorepo.github.io/)** · **[Contribution guide](https://devenv4monorepo.github.io/#contributing)**

## Why not rustup + nvm + a wiki page?

A monorepo is several languages and several products in one git history. Per-laptop installers drift. A GUI terminal is not a project dependency — you already have a window open to enter the shell. This template keeps those lifetimes apart:

- **devenv** — compilers, hooks, and a generated version matrix for *this* tree
- **Home Manager** — Alacritty + Zellij (F12), Cursor, and the CLIs you want everywhere
- **Copier** — the same answers file so the next tagged release can update the monorepo

Ubuntu 22.04 LTS (x86_64 or aarch64) is the supported host.

## Start a monorepo

```bash
# After the first tagged release:
copier copy <template-git-url> path/to/monorepo

# This checkout, including work that is not tagged yet:
copier copy --vcs-ref HEAD /path/to/devenv4monorepo path/to/monorepo
```

Answer the questionnaire (languages, min/max versions, Rust edition). Commit `.copier-answers.yml` and `devenv.local.nix`, then `./setup.sh` and `devenv shell`.

Full walkthrough: [Apply](https://devenv4monorepo.github.io/#apply) · [Bootstrap](https://devenv4monorepo.github.io/#bootstrap) · [Architecture](https://devenv4monorepo.github.io/#architecture) · [Tools](https://devenv4monorepo.github.io/#tools)
