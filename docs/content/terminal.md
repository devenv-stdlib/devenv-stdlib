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

[Cursor](https://cursor.com/) is installed from nixpkgs (`code-cursor`) via Home Manager — no website AppImage. The FHS/bwrap variant is avoided (Ubuntu 24.04 rejects unprivileged uid maps). The launcher always passes `--no-sandbox` (the store `chrome-sandbox` cannot be root-owned 4755). Nix Mesa and `--ozone-platform=x11` are added only when `systemd-detect-virt` reports `vmware`. Language packs are **not** user-global: devenv generates `.vscode/extensions.json` from `languages.*`.

| `languages.*` | Extensions |
| --- | --- |
| `rust` | rust-analyzer, CodeLLDB, Dependi |
| `go` | official Go |
| `python` | Python, Pylance, debugpy, Ruff |
| `javascript` or `typescript` | ESLint, Tailwind, pretty-ts-errors, auto-rename-tag |

Set `cursor.enable = false;` in `home.local.nix` to skip the editor install.

When `cursor.llmContext.enable` is on (default: `cursor.enable`), `home-switch` loads SecretSpec (any provider; `.env` fallback), installs RTK, Serena, and Headroom (`uv tool install` needs network the first time), merges `~/.cursor/hooks.json` and `~/.cursor/mcp.json` without replacing other entries, and starts two systemd user services:

- **9Router** (`ninerouter`) on `127.0.0.1:20128` — the API gateway (`-p 127.0.0.1:20128:20128`, image `decolua/9router:0.5.69`). Rootless Docker is the default (`DOCKER_HOST`). An in-container loopback TCP proxy sits on the published port so dashboard local-only routes (tunnel enable) see `127.0.0.1` instead of the rootlesskit peer (otherwise `Local only: CLI token required`). Dashboard: `http://127.0.0.1:20128`. `host.docker.internal` is the host default-route IPv4 (not Docker `host-gateway`: that address is the rootlesskit bridge and cannot reach host loopback). 9Router calls Headroom at `http://host.docker.internal:8787`. Log in at the dashboard with `INITIAL_PASSWORD` from gitignored `.env` (Home Manager copies it to `~/.config/9router/initial-password` before the unit starts). `~/.9router` is the container `DATA_DIR` only (rootless uid). A one-shot container hashes `INITIAL_PASSWORD` into settings so the tunnel gate sees a real password (env-only login is still “default”). Dashboard → Settings hashes are left alone. `configure-9router.sh` logs in with that password, PATCHes Headroom/RTK/Ponytail settings, and upserts `brave-search` / `firecrawl` connections named `devenv` when `BRAVE_API_KEY` / `FIRECRAWL_API_KEY` are set. `ninerouter-secrets-watch` re-runs that upsert and the Cursor `brave-search` / `firecrawl` entries in `~/.cursor/mcp.json` when `.env` is saved (inotify) or every 30s via `secretspec export` (keyring and other providers). Wrapper store paths come from the last `home-switch` (`~/.config/9router/mcp-wrappers.env`). Restart Cursor to load the new MCP servers. A locked API does not fail `home-switch` (`|| true`).
- **Headroom** (`headroom-proxy`) on port `8787` (`--host 0.0.0.0` so the container can reach the host LAN IP; check `http://127.0.0.1:8787/livez`). Sidecar saver. 9Router **Wants=** / **After=** this unit, never **Requires=**. If Headroom is down, 9Router fail-opens to providers. Headroom is **not** pointed at 9Router (that would loop).

MCP entries use Nix-store wrappers so Cursor can load `libstdc++` for the uv tools. Always upserted: Serena, Headroom (`mcp serve` against `:8787`), Context7 (`https://mcp.context7.com/mcp`), GitHub (`gh auth token`), Docker Engine (`mcp/docker:0.0.19` on the rootless socket). Brave Search (`@brave/brave-search-mcp-server@2.1.3`) and Firecrawl (`firecrawl-mcp@3.24.0`) are added only when `BRAVE_API_KEY` / `FIRECRAWL_API_KEY` are set, and removed when those keys are empty. `~/.cursor/rules/web-crawl-fallback.mdc` tells the agent to use Cursor’s browser on quota/429 — guidance only; Cursor does not auto-switch tools.

The merge does **not** set Cursor Override OpenAI Base URL — inference stays on Cursor/xAI. Set `cursor.llmContext.enable = false;` to skip this stack.
