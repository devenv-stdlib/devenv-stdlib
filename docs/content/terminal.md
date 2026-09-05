# Terminal and Cursor

The dropdown terminal is user-global via Home Manager, not `devenv shell`. The default is [Alacritty](https://alacritty.org/) running [Zellij](https://zellij.dev/), toggled by the [Quake Terminal](https://extensions.gnome.org/extension/6307/quake-terminal/) GNOME extension on **F12**. That stack renders under VMware Workstation; Warp does not. Zellij shell integration stays **off** so a `devenv shell` is not nested inside another Zellij session. fzf’s Ctrl-R is disabled; Atuin owns history search.

| Setting | Alacritty (default) | Warp (`terminal.provider = "warp"`) |
| --- | --- | --- |
| Binary | `alacritty` + Zellij | `warp-terminal` (Wayland-wrapped) |
| Dropdown | F12 Quake extension, session `quake` | Warp dedicated hotkey window |
| Height | 30% (`terminal.heightPercent`) | same option |
| Zellij theme | `dracula` (`alacritty.zellijTheme`) | n/a |
| Prompt | Starship via `~/.bashrc.d/` (Home Manager) | Starship + `honor_ps1 = true` |
| History | Atuin `daemon-fuzzy` | Warp's own history |

Only the selected provider is installed. After `home-switch` with Alacritty, **log out and back in once** so GNOME Shell loads the Quake Terminal extension.

Copy Home Manager options into `home.local.nix`:

```nix
{
  terminal.quakeKeybinding = "ctrl-`";
  alacritty.zellijTheme = "nord";
}
```

`alacritty.zellijTheme` is a built-in Zellij name ([theme list](https://zellij.dev/documentation/theme-list)). It applies after `home-switch`; start a new Zellij session to see it.

## Bash

Home Manager does **not** replace Ubuntu's `~/.bashrc`. The template writes only portable fragments: `~/.bashrc.d/00-nix.sh` (Nix installer layout via `NIX_STATE_DIR` / XDG / `~/.nix-profile`) and `~/.bashrc.d/90-home-manager.sh` (Starship, Atuin, ble.sh, direnv, aliases). `home-switch` appends a short `~/.bashrc.d` source loop to the distro file when it is missing, so an Ubuntu upgrade that resets `~/.bashrc` is fixed by running `home-switch` again. Machine-local tools (Homebrew, pyenv) go in `home.local.nix` as `home.file.".bashrc.d/10-….sh"` or an unmanaged `~/.bashrc.d/20-local.sh`.

## Cursor

[Cursor](https://cursor.com/) is installed from nixpkgs (`code-cursor`) via Home Manager — no website AppImage. The FHS/bwrap variant is avoided (Ubuntu 24.04 rejects unprivileged uid maps). The launcher always passes `--no-sandbox` (the store `chrome-sandbox` cannot be root-owned 4755). Nix Mesa and `--ozone-platform=x11` are added only when `systemd-detect-virt` reports `vmware`. Language packs are **not** user-global: devenv generates `.vscode/extensions.json` from `languages.*`.

| `languages.*` | Extensions |
| --- | --- |
| `rust` | rust-analyzer, CodeLLDB, Dependi |
| `go` | official Go |
| `python` | Python, Pylance, debugpy, Ruff |
| `javascript` or `typescript` | ESLint, Tailwind, pretty-ts-errors, auto-rename-tag |

Set `cursor.enable = false;` in `home.local.nix` to skip the editor install.
