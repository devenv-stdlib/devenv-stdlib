# Tools and CLI

A first-session tour of the programs this template installs, with a command you can run here and a link to that project's own docs. When the project is open source and publishes a donations page, that link is included so you can support it.

Commercial products (Cursor, Warp, Cachix's paid caches, GitHub) have no donation link. Projects without a published donations page are docs-only.

After `./setup.sh` and `home-switch`, the user-global CLIs are on PATH in any directory. After `devenv shell`, the project tools (`nixfmt`, `bats`, `copier`, `debtmap`, `commitlint`, …) join them.

## Platform

### Nix

The package manager everything else is built from. `setup.sh` installs the daemon (needs `sudo` once) and does **not** add your user to `trusted-users`.

```bash
nix --version
```

- Docs: [nix.dev](https://nix.dev/) · [Nix manual](https://nixos.org/manual/nix/stable/)
- Donate: [nixos.org/donate](https://nixos.org/donate/)

### devenv

[devenv](https://devenv.sh/) is the project environment: packages, `languages.*`, processes, git hooks, and tasks. Enter it in a monorepo (or this template) with `devenv shell`. The banner is `devenv4monorepo ready: <user>@<hostname>` in this checkout, or the Copier `name` in a generated monorepo.

```bash
devenv shell
devenv test          # enterTest: required binaries + BATS
devenv tasks run devenv:test-devenv
```

- Docs: [devenv.sh](https://devenv.sh/) · [Getting started](https://devenv.sh/getting-started/)

### Home Manager

[Home Manager](https://nix-community.github.io/home-manager/) owns the user profile: terminal, Starship, Cursor, bash integrations, and the CLIs under `home/*.nix`. Re-apply after editing `home.nix` or `home.local.nix`:

```bash
home-switch          # home-manager switch -b backup -f home.nix
```

Replaced files get a `.backup` suffix. On flakes-only hosts, `home-switch` and `setup.sh` set `NIX_PATH=nixpkgs=flake:nixpkgs` when `NIX_PATH` has no `nixpkgs=` entry.

- Docs: [Home Manager manual](https://nix-community.github.io/home-manager/)

### Copier

[Copier](https://copier.readthedocs.io/en/stable) copies this template into a monorepo and later merges tagged updates. It is on PATH after `home-switch` and inside `devenv shell`.

```bash
copier copy --vcs-ref HEAD /path/to/devenv4monorepo path/to/monorepo
copier update
copier check-update
```

`copier update` is how generated monorepos receive newer RTK/Serena/Headroom/9Router/MCP/debtmap pins. `update` / `devenv update` do not rewrite those files. See [Apply](#apply) and [Contribution guide](#contributing).

- Docs: [Copier](https://copier.readthedocs.io/en/stable)

### Cachix

[Cachix](https://docs.cachix.org/) is the binary cache. `setup.sh` runs `cachix use devenv` as root so you substitute devenv builds instead of compiling them. This template sets `cachix.pull = [ "devenv" ]` in `devenv.nix`. Cachix also sells private caches; there is no separate donations page.

```bash
cachix use devenv    # already done by setup.sh
```

- Docs: [Cachix](https://docs.cachix.org/)

### Docker (rootless)

This stack defaults to **rootless Docker**. `devenv shell` and `~/.bashrc.d/20-docker-rootless.sh` set `DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock` so `docker`, `act`, 9Router, and the Docker MCP talk to the user daemon even if a rootful Engine is also installed. GitHub Actions leaves `DOCKER_HOST` unset (`CI` / `GITHUB_ACTIONS`). `setup.sh` does not install Docker.

```bash
echo "$DOCKER_HOST"    # unix:///run/user/$(id -u)/docker.sock
docker info
```

Install: [Rootless mode](https://docs.docker.com/engine/security/rootless/). Then `dockerd-rootless-setuptool.sh install`, `systemctl --user enable --now docker`, and `loginctl enable-linger "$USER"`. Override with `DOCKER_HOST=unix:///var/run/docker.sock` or `docker.rootless.enable = false;` in `home.local.nix`.

- Docs: [docs.docker.com/engine/security/rootless](https://docs.docker.com/engine/security/rootless/)

### direnv

[direnv](https://direnv.net/) loads the devenv when you `cd` into the repo (`.envrc` is committed). Home Manager installs direnv + nix-direnv and hooks bash.

```bash
direnv allow         # once per clone
```

Alternatively, without direnv: add `eval "$(devenv hook bash)"` to `~/.bashrc.d/99-devenv-hook.sh` or `programs.bash.initExtra` in `home.local.nix`, then `devenv allow` here.

- Docs: [direnv](https://direnv.net/) · [nix-direnv](https://github.com/nix-community/nix-direnv)

## Everyday CLI

These are user-global (Home Manager) unless noted.

### git

Version control. The tag guard and `prek` hooks wrap `git commit` and `git tag`.

```bash
git status
git commit           # pre-commit + commitlint
```

- Docs: [git-scm.com](https://git-scm.com/doc)
- Donate: [Git via Software Freedom Conservancy](https://git-scm.com/sfc/)

### gh

[GitHub CLI](https://cli.github.com/manual/) for pull requests, checks, and releases. `semantic-release` in CI uses the GitHub API; `gh` is what you use locally.

```bash
gh auth login
gh pr status
```

- Docs: [GitHub CLI](https://cli.github.com/manual/)

### jq, ripgrep, fd

JSON, search, and find. `rg` respects `.gitignore`. `fd` is the `find` replacement.

```bash
jq . copier.yml
rg 'supported.rust.min'
fd devenv.local.nix
```

- jq docs: [jqlang.github.io/jq](https://jqlang.github.io/jq/)
- ripgrep docs: [GUIDE](https://github.com/BurntSushi/ripgrep/blob/master/GUIDE.md) · Donate: [BurntSushi](https://github.com/sponsors/BurntSushi)
- fd docs: [sharkdp/fd](https://github.com/sharkdp/fd) · Donate: [sharkdp](https://github.com/sponsors/sharkdp)

### bat, eza, fzf, zoxide, delta

Home Manager aliases `cat` → [bat](https://github.com/sharkdp/bat) and `ls` / `ll` / `la` / `lt` / `lla` → [eza](https://eza.rocks/). [fzf](https://junegunn.github.io/fzf/) is wired into bash. [zoxide](https://github.com/ajeetdsouza/zoxide) (`z`) jumps to frequent directories. [delta](https://dandavison.github.io/delta/) is the git pager (`programs.git`).

```bash
ll
z devenv4monorepo
git diff             # delta
```

- bat: [sharkdp/bat](https://github.com/sharkdp/bat) · Donate: [sharkdp](https://github.com/sponsors/sharkdp)
- eza: [eza.rocks](https://eza.rocks/) · Donate: [cafkafk](https://github.com/sponsors/cafkafk)
- fzf: [junegunn.github.io/fzf](https://junegunn.github.io/fzf/)
- zoxide: [ajeetdsouza/zoxide](https://github.com/ajeetdsouza/zoxide)
- delta: [dandavison.github.io/delta](https://dandavison.github.io/delta/)

### httpie, tldr, howdoi, fuck, usql

[HTTPie](https://httpie.io/docs/cli) is `http`. nixpkgs has no explainshell, so Home Manager installs [tealdeer](https://github.com/tealdeer-rs/tealdeer) as `tldr`. `howdoi` answers “how do I…” from Stack Overflow ([gleitz/howdoi](https://github.com/gleitz/howdoi); packaged here because nixpkgs dropped it). [pay-respects](https://codeberg.org/iff/pay-respects) is aliased to `fuck` (nixpkgs dropped thefuck). [usql](https://github.com/xo/usql) is built with the `all` driver tag.

```bash
http https://endoflife.date/api/rust.json
tldr tar
howdoi reverse a list in python
# mistype a command, then:
fuck
```

- HTTPie: [httpie.io/docs/cli](https://httpie.io/docs/cli)
- tldr pages: [tldr.sh](https://tldr.sh/) · tealdeer: [tealdeer-rs/tealdeer](https://github.com/tealdeer-rs/tealdeer)
- howdoi: [gleitz/howdoi](https://github.com/gleitz/howdoi)
- pay-respects: [codeberg.org/iff/pay-respects](https://codeberg.org/iff/pay-respects)
- usql: [xo/usql](https://github.com/xo/usql)

## Terminal

The dropdown is Alacritty + Zellij + Quake Terminal on **F12** (default). After the first `home-switch`, log out and back in once so GNOME Shell loads the extension. Details and Warp: [Terminal and Cursor](#terminal).

### Alacritty

GPU terminal. Quake session `quake` (no decorations); dash icon opens session `main`.

- Docs: [alacritty.org](https://alacritty.org/)

### Zellij

Multiplexer inside Alacritty. Open a pane, then attach again and the layout is still there. Theme defaults to `dracula` (`alacritty.zellijTheme`).

- Docs: [zellij.dev/documentation](https://zellij.dev/documentation/)
- Donate: [zellij.dev/stickers](https://zellij.dev/stickers/) (GitHub Sponsors, Ko-fi, Liberapay)

### Quake Terminal

GNOME extension that drops the terminal from the top of the screen.

- Docs: [extensions.gnome.org](https://extensions.gnome.org/extension/6307/quake-terminal/)

### Starship, Atuin, ble.sh

[Starship](https://starship.rs/) is the prompt (Home Manager writes it to `~/.bashrc.d/`). [Atuin](https://docs.atuin.sh/) is history search (`search_mode = "daemon-fuzzy"`, user-systemd daemon). [ble.sh](https://github.com/akinomyoga/ble.sh) adds line-editor highlighting, then Atuin. Warp uses its own history and editor instead.

```bash
# Atuin: Ctrl-R in bash (after home-switch)
```

- Starship: [starship.rs](https://starship.rs/) · Donate: [Open Collective](https://opencollective.com/starship)
- Atuin: [docs.atuin.sh](https://docs.atuin.sh/) · Donate: [atuinsh](https://github.com/sponsors/atuinsh)
- ble.sh: [akinomyoga/ble.sh](https://github.com/akinomyoga/ble.sh)

## Editor

### Cursor

[Cursor](https://cursor.com/) is installed from nixpkgs (`code-cursor`) via Home Manager — no website AppImage. The launcher always passes `--no-sandbox`. Common extensions (devenv, Nix IDE, EditorConfig, …) are user-global. Language packs follow `languages.*` and are installed when you `devenv shell`.

```bash
# skip the editor
# home.local.nix: cursor.enable = false;
```

`cursor.llmContext.enable` (default: `cursor.enable`) installs RTK, Serena, Headroom, 9Router, and Cursor MCP servers and merges hooks/MCP. It does **not** set Override OpenAI Base URL.

- Docs: [cursor.com/docs](https://cursor.com/docs)

### RTK

[RTK](https://github.com/rtk-ai/rtk) (`rtk-ai/rtk`, not crates.io) rewrites Cursor Agent shell commands so the model sees compact output. Home Manager pins the official release binary and merges a `preToolUse` Shell hook into `~/.cursor/hooks.json`. It does not run `rtk init`.

```bash
rtk rewrite "git status"
```

- Docs: [rtk-ai/rtk](https://github.com/rtk-ai/rtk)
- Donate: [github.com/sponsors/rtk-ai](https://github.com/sponsors/rtk-ai)

### Headroom

[Headroom](https://github.com/headroomlabs-ai/headroom) is a sidecar saver for 9Router plus MCP retrieve/stats. Home Manager installs `headroom-ai[proxy,mcp]` with `uv tool install` and runs `headroom-proxy` (`0.0.0.0:8787` so a rootless container can reach the host LAN IP; host check is still `http://127.0.0.1:8787/livez`). 9Router calls `http://host.docker.internal:8787` from the container when Headroom is up and fail-opens if it is down. Headroom is not Cursor model traffic and must not use 9Router as `--openai-api-url` (loop).

```bash
headroom --help
```

- Docs: [docs.headroomlabs.ai](https://docs.headroomlabs.ai/docs)

### Serena

[Serena](https://github.com/oraios/serena) is Headroom’s code-memory MCP (symbol graph). Home Manager installs `serena-agent` with `uv tool install` and upserts the `serena` server in `~/.cursor/mcp.json` (`--context ide`). devenv writes `.serena/project.yml` from `languages.*` (`language_servers` always includes `nix`). Serena starts its own language servers; they are not Cursor’s. Override in `.serena/project.local.yml`.

```bash
serena start-mcp-server --help
```

- Docs: [oraios.github.io/serena](https://oraios.github.io/serena/)
- Donate: [github.com/sponsors/oraios](https://github.com/sponsors/oraios)

### 9Router

[9Router](https://github.com/decolua/9router) is the local API gateway (`decolua/9router:0.5.69`). Home Manager starts the `ninerouter` user service with `-p 127.0.0.1:20128:20128` (rootless Docker is the default; not `--network host`) and `--add-host=host.docker.internal:<host IPv4>`. A loopback TCP proxy inside the container forwards that published port to 9Router on `127.0.0.1` so dashboard local-only routes (tunnel enable) do not demand a CLI token. Docker `host-gateway` is the bridge in the rootlesskit netns and does not reach host loopback, so the start script uses the host default-route address (`NINEROUTER_HOST_IP` overrides). It then PATCHes settings (`rtkEnabled`, `headroomEnabled`, `headroomUrl: http://host.docker.internal:8787`, Ponytail on, Caveman off). The host curl to 9Router stays `http://127.0.0.1:20128`. Open that URL to log in with `INITIAL_PASSWORD` from gitignored `.env` (copied to `~/.config/9router/initial-password` **before** the unit starts). The start script hashes `INITIAL_PASSWORD` into settings so the tunnel gate (`hasPassword`) is satisfied. Env-only login is still the default password until that hash exists. A custom hash from Dashboard → Settings is not overwritten. `~/.9router` is rootless-owned `DATA_DIR`. A locked `/api/settings` does not fail `home-switch`.

```bash
# after home-switch, with Docker on PATH
curl -fsS http://127.0.0.1:20128/livez || curl -fsS http://127.0.0.1:20128/
```

- Docs: [github.com/decolua/9router](https://github.com/decolua/9router) · [9router.com](https://9router.com)

### Context7

[Context7](https://github.com/upstash/context7) is a remote MCP for up-to-date library docs. Home Manager upserts `https://mcp.context7.com/mcp` into `~/.cursor/mcp.json`. No API key is asked at copy time.

- Docs: [github.com/upstash/context7](https://github.com/upstash/context7)
- Donate: [github.com/sponsors/upstash](https://github.com/sponsors/upstash)

### GitHub MCP

The official [github-mcp-server](https://github.com/github/github-mcp-server) (1.11.0) runs over stdio. A wrapper sets `GITHUB_PERSONAL_ACCESS_TOKEN` from `gh auth token` and warns if you have not logged in.

```bash
gh auth login
```

- Docs: [github/github-mcp-server](https://github.com/github/github-mcp-server)

### Docker Engine MCP

Host Docker Engine tools via `docker run -i --rm -v $XDG_RUNTIME_DIR/docker.sock:/var/run/docker.sock mcp/docker:0.0.19` — not the Docker MCP Gateway. The wrapper uses the rootless socket (`DOCKER_HOST` if you set it). It warns if `docker` or that socket is missing.

- Docs: [hub.docker.com/r/mcp/docker](https://hub.docker.com/r/mcp/docker)

### Brave Search

Optional. Copier asks for a [Brave Search API](https://brave.com/search/api/) key. Empty skips the MCP. The key lives in gitignored `.env` / SecretSpec, not `.copier-answers.yml`. Home Manager upserts the official `@brave/brave-search-mcp-server@2.1.3` (`npx -y`, STDIO) when `BRAVE_API_KEY` is set. The same key is POSTed to 9Router as a `brave-search` connection named `devenv` after dashboard login (`configure-9router.sh`).

- Docs: [Brave Search API](https://brave.com/search/api/) · [brave-search-mcp-server](https://github.com/brave/brave-search-mcp-server)

### Firecrawl

Optional. Copier asks for a [Firecrawl](https://www.firecrawl.dev/) API key (free tier). Empty skips the MCP. Same SecretSpec / `.env` path as Brave. Home Manager upserts `firecrawl-mcp@3.24.0` (`npx -y`) when `FIRECRAWL_API_KEY` is set. The same key is upserted into 9Router as a `firecrawl` connection named `devenv`.

- Docs: [Firecrawl](https://www.firecrawl.dev/) · [MCP](https://docs.firecrawl.dev/mcp-server)

### Neovim and nano

User-global [Neovim](https://neovim.io/) (no plugins yet) and [nano](https://www.nano-editor.org/) with bundled syntax files.

- Neovim: [neovim.io](https://neovim.io/) · Donate: [neovim.io/sponsors](https://neovim.io/sponsors/)
- nano: [nano-editor.org](https://www.nano-editor.org/)

## Quality and release

### prek

[prek](https://prek.j178.dev/) runs the hooks in `modules/git-hooks.nix` (`pre-commit` and `commit-msg`). devenv generates the config; do not commit a hand-edited `.pre-commit-config.yaml`. `reference-transaction` is installed separately so `git tag` is gated.

```bash
# hooks run on git commit; devenv shell installs them
```

- Docs: [prek.j178.dev](https://prek.j178.dev/)

### commitlint and semantic-release

Subjects must be [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, `ci:`, `test:`, `chore:`). [commitlint](https://commitlint.js.org/) is the `commit-msg` hook (`commitlint.config.mjs`). On push to `master`/`main`, [semantic-release](https://semantic-release.gitbook.io/semantic-release/) (user-global CLI, CI uses `.releaserc.json`) versions and publishes a GitHub Release. Those tags drive `copier copy` / `copier update`.

- Conventional Commits: [conventionalcommits.org](https://www.conventionalcommits.org/)
- commitlint: [commitlint.js.org](https://commitlint.js.org/)
- semantic-release: [handbook](https://semantic-release.gitbook.io/semantic-release/)

### Formatters, linters, and secrets

Always-on in the devenv hook set: [nixfmt](https://github.com/NixOS/nixfmt), [statix](https://github.com/oppiliappan/statix), [deadnix](https://github.com/astro/deadnix), [ShellCheck](https://www.shellcheck.net/), [typos](https://github.com/crate-ci/typos), [proselint](https://github.com/amperser/proselint), [lychee](https://lychee.cli.rs/), [actionlint](https://github.com/rhysd/actionlint), [yamlfmt](https://github.com/google/yamlfmt), [Gitleaks](https://gitleaks.io/). Language hooks (rustfmt, ruff, prettier, …) follow `languages.*`.

- nixfmt: [NixOS/nixfmt](https://github.com/NixOS/nixfmt)
- ShellCheck: [shellcheck.net](https://www.shellcheck.net/)
- Gitleaks: [gitleaks.io](https://gitleaks.io/)
- lychee: [lychee.cli.rs](https://lychee.cli.rs/)

### debtmap

[debtmap](https://github.com/iepathos/debtmap) 0.23.0 (official release binaries in `modules/debtmap-pkg.nix`) runs when any of rust/python/javascript/typescript/go is on. `devenv shell` writes `.debtmap.toml` (gitignored). Override thresholds in `devenv.local.nix`.

```bash
debtmap --help
```

- Docs: [iepathos/debtmap](https://github.com/iepathos/debtmap)

### BATS and act

[BATS](https://bats-core.readthedocs.io/) is the shell test runner (`bats -r tests`). [act](https://nektosact.com/) replays GitHub Actions locally; `test-devenv` builds `devenv-act:24.04` and runs `act workflow_call` on generated workflows. `.actrc` maps both `ubuntu-24.04` and `ubuntu-26.04` to that image. `act` is also user-global (`home/act.nix`). Local act uses the rootless Engine (`DOCKER_HOST`).

```bash
bats -r tests
build-act-image
```

- BATS: [bats-core.readthedocs.io](https://bats-core.readthedocs.io/)
- act: [nektosact.com](https://nektosact.com/)

### endoflife.date

The catalog script fetches cycle/EOL data from [endoflife.date](https://endoflife.date). Template authors run:

```bash
refresh-toolchain-latest
```

- Docs: [endoflife.date](https://endoflife.date)

## This documentation site

Live site: [devenv4monorepo.github.io](https://devenv4monorepo.github.io/). Vite + React, [Spectrum](https://spectrum.adobe.com/) web components via [`@lit/react`](https://lit.dev/docs/frameworks/react/), and `react-markdown` + `remark-gfm`. Content is `docs/content/*.md` imported with `?raw`. Template-only (not copied into monorepos). How to edit it: [Contribution guide](#contributing).

```bash
docs-dev             # http://localhost:5173
docs-build           # docs/dist
```

- Vite: [vite.dev](https://vite.dev/)
- React: [react.dev](https://react.dev/)
- Spectrum: [spectrum.adobe.com](https://spectrum.adobe.com/)
- Lit + React: [lit.dev](https://lit.dev/docs/frameworks/react/)
