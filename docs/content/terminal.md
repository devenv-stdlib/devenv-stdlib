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

Home Manager does **not** replace Ubuntu's `~/.bashrc`. The template writes only portable fragments: `~/.bashrc.d/00-nix.sh` (Nix installer layout via `NIX_STATE_DIR` / XDG / `~/.nix-profile`) and `~/.bashrc.d/90-home-manager.sh` (Starship, Atuin, ble.sh, direnv, aliases). `home-switch` appends a short `~/.bashrc.d` source loop to the distro file when it is missing, so an Ubuntu upgrade that resets `~/.bashrc` is fixed by running `home-switch` again.

Add machine-local snippets with `home.file` in `home.local.nix`. Files in `~/.bashrc.d/` are sourced in name order, so `10-host.sh` runs after Nix and before Starship.

```nix
{
  home.file.".bashrc.d/10-host.sh".text = ''
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"
    eval "$(pyenv init -)"
  '';
}
```

Then `home-switch` and open a new terminal. An unmanaged `~/.bashrc.d/20-local.sh` also works; Home Manager will not overwrite it. `programs.bash.initExtra` in `home.local.nix` appends to `90-home-manager.sh` instead.

## Cursor

[Cursor](https://cursor.com/) is installed from nixpkgs (`code-cursor`) via Home Manager (`home/ides/`) — no website AppImage. The FHS/bwrap variant is avoided (Ubuntu 24.04 rejects unprivileged uid maps). The launcher always passes `--no-sandbox` (the store `chrome-sandbox` cannot be root-owned 4755). That flag is **Chromium only**, not the Agent terminal sandbox. On Ubuntu with `kernel.apparmor_restrict_unprivileged_userns=1` (default), Agent Shell needs AppArmor profiles so `cursorsandbox` can create a user namespace and configure loopback; `./setup.sh` installs [`includes/cursor-agent-sandbox/`](../../includes/cursor-agent-sandbox/) as root (`sudo includes/cursor-agent-sandbox/install.sh` to re-apply after a Cursor upgrade). Nix Mesa and `--ozone-platform=x11` are added only when `systemd-detect-virt` reports `vmware`. Language packs are **not** user-global: language tool presets (`presets/lang/<lang>/*.nix) generate `.vscode/extensions.json` from `languages.*`.

| `languages.*` | Extensions |
| --- | --- |
| `rust` | rust-analyzer, CodeLLDB, Dependi |
| `go` | official Go |
| `python` | Python, Pylance, debugpy, Ruff |
| `javascript` or `typescript` | ESLint, Tailwind, pretty-ts-errors, auto-rename-tag |

Set `cursor.enable = false;` in `home.local.nix` to skip the editor install. Set `vscode.enable = true;` to opt into the VS Code app (off by default).

When `cursor.llmContext.enable` is on (default: `cursor.enable`), `home-switch` loads SecretSpec (any provider; `.env` fallback), merges `~/.cursor/mcp.json` from the shared MCP catalog without replacing other entries, runs `mise install` for user-scope catalog CLIs, ensures `~/.serena/serena_config.yml` excludes `search_for_pattern`, writes Ponytail and Headroom rules under `~/.cursor/rules/`, and starts `mcp-secrets-watch`. First install needs network.

Activation also cleans retired RTK / 9Router leftovers (disable old units, strip managed Shell hooks and RTK allowlist entries, remove `$HOME/.cursor/bin/rtk` and `rtk-passthrough.mdc`). Wrapper store paths for Brave/Firecrawl live in `~/.config/devenv4monorepo/mcp-wrappers.env`.

`mcp-secrets-watch` re-runs Cursor `brave-search` / `firecrawl` entries in `~/.cursor/mcp.json` when `.env` is saved (inotify) or every 30s via `secretspec export`. Restart Cursor to load the new MCP servers.

MCP entries use mise shims (or Nix when the catalog promotes a tool). Always upserted: Serena, Headroom (`headroom mcp serve`), Context7 (`https://mcp.context7.com/mcp`), git-conflict-mcp, and git-rebase-mcp. Brave Search is added only when `BRAVE_API_KEY` is set. Firecrawl defaults to the hosted **slim** URL (`https://mcp.firecrawl.dev/v2/mcp`) when `FIRECRAWL_API_KEY` is set or `FIRECRAWL_MCP_PROFILE=slim`; set `FIRECRAWL_MCP_PROFILE=full` (with a key) for local full-surface `firecrawl-mcp`. Entries are removed when those enable signals are empty. Prefer authenticated `gh` for GitHub API work (see `.agents/skills/gh-cli`); the retired GitHub MCP is removed from `~/.cursor/mcp.json` on `home-switch`. Prefer the `docker` CLI on the rootless socket for Engine work; the retired Docker MCP is removed from `~/.cursor/mcp.json` on `home-switch`. `~/.cursor/rules/web-crawl-fallback.mdc` tells the agent to use Cursor’s browser on MCP quota/429 — guidance only. Set `cursor.llmContext.enable = false;` to skip this stack.
