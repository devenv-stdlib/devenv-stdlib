# Terminal and Cursor

The dropdown terminal is user-global via Home Manager, not `devenv shell`. The default is [Alacritty](https://alacritty.org/) running [Zellij](https://zellij.dev/), toggled by the [Quake Terminal](https://extensions.gnome.org/extension/6307/quake-terminal/) GNOME extension on **F12**. That stack renders under VMware Workstation; Warp does not. Zellij shell integration stays **off** so a `devenv shell` is not nested inside another Zellij session. fzf’s Ctrl-R is disabled; Atuin owns history search.

| Setting | Alacritty (default) | Warp (`terminal.provider = "warp"`) |
| --- | --- | --- |
| Binary | `alacritty` + Zellij | `warp-terminal` (Wayland-wrapped) |
| Dropdown | F12 Quake extension, session `quake` | Warp dedicated hotkey window |
| Height | 30% (`terminal.heightPercent`) | same option |
| Prompt | Starship via Home Manager `programs.bash` | Starship + `honor_ps1 = true` |
| History | Atuin `daemon-fuzzy` | Warp's own history |

Only the selected provider is installed. After `home-switch` with Alacritty, **log out and back in once** so GNOME Shell loads the Quake Terminal extension.

Copy Home Manager options into `home.local.nix`:

```nix
{
  terminal.provider = "warp";
  terminal.quakeKeybinding = "ctrl-`";
}
```

## Cursor

[Cursor](https://cursor.com/) is installed from nixpkgs (`code-cursor`) via Home Manager — no website AppImage. The FHS/bwrap variant is avoided (Ubuntu 24.04 rejects unprivileged uid maps). The launcher always passes `--no-sandbox` (the store `chrome-sandbox` cannot be root-owned 4755). Nix Mesa and `--ozone-platform=x11` are added only when `systemd-detect-virt` reports `vmware`. Language packs are **not** user-global: devenv generates `.vscode/extensions.json` from `languages.*`.

| `languages.*` | Extensions |
| --- | --- |
| `rust` | rust-analyzer, CodeLLDB, Dependi |
| `go` | official Go |
| `python` | Python, Pylance, debugpy, Ruff |
| `javascript` or `typescript` | ESLint, Tailwind, pretty-ts-errors, auto-rename-tag |

Set `cursor.enable = false;` in `home.local.nix` to skip the editor install.
