# Multi-OS classes (Phase 5)

Same aspects grow `nixos` / `darwin` without forking feature definitions.
Ubuntu `den.homes` + `home-switch` remain the supported activation path.

## Host stubs

| Host | System | Class | Flake output |
| --- | --- | --- | --- |
| `fixture-nixos` | `x86_64-linux` | `nixos` | none (`intoAttr = []`) |
| `fixture-darwin` | `aarch64-darwin` | `darwin` | none (`intoAttr = []`) |

Declared in `den/hosts.nix`. Instantiation is stubbed; real `nixosConfigurations` /
`darwinConfigurations` wait on product host matrix + nix-darwin input.

## Portable aspect

`shell-tools` ships one shared `denOsPortable` payload on **both** `nixos` and
`darwin` (same let-bound attrset — no copy-paste). Tool list mirrors the CLIs
already installed for Ubuntu via `home-cli` (ripgrep, fd, bat, fzf, direnv,
zoxide + shell integrations).

Eval: `nix eval .#denOsClasses` / `tests/unit/den-os-classes.nix`.

## Unsupported on Darwin / NixOS (Ubuntu-only)

| Piece | Why | Guard |
| --- | --- | --- |
| Alacritty + Quake GNOME extension | Needs GNOME Shell + dconf | `alacritty-quake` has **no** `nixos`/`darwin` keys |
| Warp + GNOME custom keybinding | Wayland/GNOME shortcut path | `warp-quake` has **no** `nixos`/`darwin` keys |
| `terminal` hub GNOME dash sync | Ubuntu sidebar / gsettings | HM-only via `home/terminal.nix` |
| `targets.genericLinux` | Non-NixOS Linux HM | stays on `den.default.homeManager` (Ubuntu) |

Do **not** revive a parallel legacy HM root for multi-OS. Darwin/NixOS user
profiles, when product needs them, extend aspects + `den.hosts` — not `home.nix`.
