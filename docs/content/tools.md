# Tools and CLI

A first-session tour of the programs this package installs, with a command you can run here and a link to that project's own docs. When the project is open source and publishes a donations page, that link is included so you can support it.

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

[devenv](https://devenv.sh/) is the project environment: packages, `languages.*`, processes, git hooks, and tasks. Enter it in a monorepo (or this dogfood checkout) with `devenv shell`. The banner is `devenv4monorepo ready: <user>@<hostname>` here, or the `name` from `devenv.local.nix` in a consumer.

```bash
devenv shell
devenv test          # enterTest: required binaries + BATS
devenv tasks run --show-output devenv:test-devenv            # unit then integration
devenv tasks run --show-output devenv:test-devenv-unit       # nix-unit + BATS
devenv tasks run --show-output devenv:test-devenv-integration
```

- Docs: [devenv.sh](https://devenv.sh/) · [Getting started](https://devenv.sh/getting-started/)

### Home Manager

[Home Manager](https://nix-community.github.io/home-manager/) owns the user profile: terminal, Starship, Cursor, bash integrations, and the CLIs under `home/*.nix` (composed via Den aspects). Re-apply after editing Den aspects or `home.local.nix`:

```bash
home-switch          # home-manager switch -b backup --flake .#developer --impure
```

Replaced files get a `.backup` suffix. On flakes-only hosts, `home-switch` and `setup.sh` set `NIX_PATH=nixpkgs=flake:nixpkgs` when `NIX_PATH` has no `nixpkgs=` entry, and drop search-path directories that do not exist (such as `~/.nix-defexpr/channels` without channels), which Nix would otherwise warn about on every evaluation.

- Docs: [Home Manager manual](https://nix-community.github.io/home-manager/)

### Copier

[Copier](https://copier.readthedocs.io/en/stable) stays on PATH after `home-switch` and inside `devenv shell` as a general scaffolding CLI (reserved for a future projects feature). **devenv-stdlib is consumed via a Nix flake pin**, not `copier copy`. See [Consume the package](#apply).

```bash
copier --version
```

- Docs: [Copier](https://copier.readthedocs.io/en/stable)

### Cachix

[Cachix](https://docs.cachix.org/) is the binary cache. `setup.sh` runs `cachix use devenv` as root so you substitute devenv builds instead of compiling them; CI gets the same cache from `cachix-action`. `devenv.nix` sets `cachix.enable = false` because the cache is already in `nix.conf` and devenv's own pull would add it a second time, which Nix reports as a warning. Cachix also sells private caches; there is no separate donations page.

```bash
cachix use devenv    # already done by setup.sh
```

- Docs: [Cachix](https://docs.cachix.org/)

### Docker (rootless)

This stack defaults to **rootless Docker**. `devenv shell` and `~/.bashrc.d/20-docker-rootless.sh` set `DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock` so `docker` and `act` talk to the user daemon even if a rootful Engine is also installed. GitHub Actions leaves `DOCKER_HOST` unset (`CI` / `GITHUB_ACTIONS`). `setup.sh` does not install Docker.

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
nix flake metadata
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

### httpie, tldr, navi, fuck, usql

[HTTPie](https://httpie.io/docs/cli) is `http`. nixpkgs has no explainshell, so Home Manager installs [tealdeer](https://github.com/tealdeer-rs/tealdeer) as `tldr`. [navi](https://github.com/denisidoro/navi) browses interactive cheatsheets: repo-local sheets in `cheats/` (prepended to `NAVI_PATH` in `devenv shell`) plus [denisidoro/cheats](https://github.com/denisidoro/cheats) from Home Manager. Each stdlib tool leaf has `cheats/<leaf>.cheat` (use `navi <tool name>`; the stdlib status report prints that hint). [pay-respects](https://codeberg.org/iff/pay-respects) is aliased to `fuck` (nixpkgs dropped thefuck). [usql](https://github.com/xo/usql) is built with the `all` driver tag.

```bash
http https://endoflife.date/api/rust.json
tldr tar
navi
# mistype a command, then:
fuck
```

- HTTPie: [httpie.io/docs/cli](https://httpie.io/docs/cli)
- tldr pages: [tldr.sh](https://tldr.sh/) · tealdeer: [tealdeer-rs/tealdeer](https://github.com/tealdeer-rs/tealdeer)
- navi: [denisidoro/navi](https://github.com/denisidoro/navi) · cheats: [denisidoro/cheats](https://github.com/denisidoro/cheats) · syntax: [cheatsheet syntax](https://github.com/denisidoro/navi/blob/master/docs/cheatsheet/syntax/README.md)
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

[Cursor](https://cursor.com/) is installed from nixpkgs (`code-cursor`) via Home Manager (`home/ides/cursor.nix`) — no website AppImage. The launcher always passes `--no-sandbox` (Chromium only; the store `chrome-sandbox` cannot be root-owned 4755). Agent terminal sandbox is separate: on Ubuntu, `./setup.sh` installs AppArmor profiles under `includes/cursor-agent-sandbox/`. Common extensions (devenv, navi cheatsheet language, Nix IDE, EditorConfig, …) are user-global under `~/.cursor/extensions`. Language packs follow `languages.*` and are installed when you `devenv shell` (`presets/<lang>/<category>/*.nix`, `cursor-sync-extensions`). Users may add their own extensions; sync only adds missing links.

```bash
# skip the editor
# home.local.nix: cursor.enable = false;
```

`cursor.llmContext.enable` (default: `cursor.enable`) installs Serena, Headroom, Context7, git-conflict-mcp, git-rebase-mcp, and optional Brave/Firecrawl MCP from the shared `home/ides/mcp` catalog and merges them into `~/.cursor/mcp.json` (upsert only; user-added MCP servers are preserved; the retired `github` and `docker` catalog keys are removed). It also writes the user-global Ponytail and Headroom Cursor rules. `mcp-secrets-watch` re-upserts Brave/Firecrawl when SecretSpec / `.env` keys change (wrappers under `~/.config/devenv4monorepo/`).

- Docs: [cursor.com/docs](https://cursor.com/docs)

### VS Code

Opt-in only (`vscode.enable = true` in `home.local.nix`; default **false**). Installs `pkgs.vscode` and common extensions under `~/.vscode/extensions`. Does not turn on with Cursor. Language packs use `vscode-sync-extensions` when you want them under `~/.vscode/extensions`.

### Non-Nix catalog and mise

Pins for tools that are not (yet) taken from nixpkgs live in `modules/non-nix/catalog.toml` (each `[[tool]]` has a one-line comment pointing at upstream docs). Monorepos add team tools in `modules/non-nix/catalog.local.toml` (same shape; committed; copy from root `catalog.local.toml.example`). At eval time, CLI entries promote to a Nix package when the attr exists, `lib.versionAtLeast` meets the pin, and `homepage`/`pname` matches `homepageContains`. Otherwise [mise](https://mise.jdx.dev/) installs them. Duplicate names across the two files fail evaluation.

Add or remove entries with flag-first tasks (creates `catalog.local.toml` from root `catalog.local.toml.example` when missing):

```bash
# Team / monorepo (catalog.local.toml)
devenv tasks run non-nix:add-local -- --name example-cli --kind cli --scope project \
  --pin 1.0.0 --mise ubi:owner/example-cli \
  --docs 'Example CLI. Docs: https://example.com'
devenv tasks run non-nix:remove-local -- --name example-cli

# Package authors only (catalog.toml; refuses without includes/update/)
devenv tasks run non-nix:add -- --name example-cli --kind cli --scope project \
  --pin 1.0.0 --mise ubi:owner/example-cli \
  --docs 'Example CLI. Docs: https://example.com'
devenv tasks run non-nix:remove -- --name example-cli
```

Pass `--dry-run` to preview. Each command’s `--help` includes copy-pasteable Examples.

| Scope                                                                  | Config                                       | Install                             |
| ---------------------------------------------------------------------- | -------------------------------------------- | ----------------------------------- |
| Project (`debtmap`, `skills`, plus `catalog.local.toml` project-scope) | generated `mise.toml` (gitignored)           | `mise:install` after `devenv:files` |
| User (Serena, Headroom, MCP CLIs, navi, …)                             | `~/.config/mise/conf.d/devenv4monorepo.toml` | `home-switch` activation            |

Docker images (when present in the catalogs) and the devenv VS Code extension share the same catalogs but are not mise `[tools]` — activation/`docker pull` and Marketplace fetch handle those. Languages stay on devenv; the generated TOML disables mise’s `python`/`node`/`rust`/`go` tools and sets `pipx.uvx = true` so catalog `pipx:` CLIs use `uv tool install` (Home Manager and devenv `mise:install` put `uv` on PATH; no host `pipx` required). Package authors bump shipped pins with `update` → `includes/update/non-nix.sh`. In a consumer tree, `update` runs `devenv update` then refreshes `catalog.local.toml` (Nix when promotable, else `mise install`); consumers get framework pin moves by bumping `devenv-stdlib`.

### Agent skills

`.agents/skills/` ships 54 upstream Cursor skills (project scope; Cursor reads that directory natively), vendored with the [Vercel skills CLI](https://github.com/vercel-labs/skills). `skills-lock.json` records each skill's source and content hash. Only a skill's name and description sit in context until the agent decides it is relevant; bodies load on demand. Sources: [obra/superpowers](https://github.com/obra/superpowers) (brainstorming, plans, TDD, debugging, code review, worktrees), [mattpocock/skills](https://github.com/mattpocock/skills) (spec/tickets/triage, codebase design, grill-me, handoff), [cursor/plugins](https://github.com/cursor/plugins) (`cursor-team-kit` PR/CI flows, `pstack` unslop/no-comments/principles, `cli-for-agents`), [trailofbits/skills](https://github.com/trailofbits/skills) (Python/Rust review, property-based and mutation testing, differential review, supply-chain and Actions auditors, second opinion), and Anthropic's `mcp-builder`. The per-skill table with licenses (MIT, CC-BY-SA-4.0, Apache-2.0) is `.agents/skills/README.md`.

```bash
skills add owner/repo --skill <name> -a cursor -y   # add one (repo root; mise PATH)
skills remove <name>
skills list
```

In this publisher checkout, `update` runs `includes/update/skills.sh` (`skills update -y -p` after project `mise install`); review the diff before committing, since skills run with the agent's permissions. Consumers receive skill/pin changes by bumping `devenv-stdlib`. Git hooks skip `.agents/skills/` (vendored text). Excluded on purpose: duplicate TDD/debugging skills, Claude-Code-only bootstrap and subagent skills, hook-driven plugins (`ralph-loop`, `advisor`, `continual-learning`), Anthropic document/Claude-API skills, vendor-product skills, smart-contract and fuzzing suites, and rule bundles such as awesome-cursorrules (always-apply, stale).

- Docs: [Cursor skills](https://cursor.com/docs/skills), [agentskills.io](https://agentskills.io), [skills.sh](https://skills.sh/)

### Headroom

[Headroom](https://github.com/headroomlabs-ai/headroom) is official MCP (`headroom_compress` / `retrieve` / `stats`). Home Manager installs `headroom-ai` via mise (`pipx:` backend → `uv tool install`; `uv` is on the activation PATH) from the non-Nix catalog and upserts `headroom mcp serve` (no `--proxy-url`, no `headroom-proxy` unit). The agent must call those tools; nothing runs after every prompt. `.cursor/rules/headroom-compress.mdc` (also `~/.cursor/rules/headroom-compress.mdc` after `home-switch`) tells the agent to compress only large tool output or pastes.

```bash
headroom --help
```

- Docs: [docs.headroomlabs.ai](https://docs.headroomlabs.ai/docs)

### Serena

[Serena](https://github.com/oraios/serena) is Headroom’s code-memory MCP (symbol graph). Home Manager installs `serena-agent` via mise (`pipx:` backend → `uv tool install`) from the non-Nix catalog and upserts the `serena` server in `~/.cursor/mcp.json` (`--context ide --open-web-dashboard false` so the dashboard stays available but does not open a browser tab on every MCP start). On the same activation, it merges `excluded_tools: [search_for_pattern]` into `~/.serena/serena_config.yml` (creates the file if missing; preserves Serena-managed keys such as `projects` / `auth_secret`). Cursor Instant Grep / Grep stays the lexical content-search path; Serena keeps symbol tools. devenv writes `.serena/project.yml` from `languages.*` (`language_servers` always includes `nix`). Serena starts its own language servers; they are not Cursor’s. Override project settings in `.serena/project.local.yml` (exclusions still extend from the global config).

```bash
serena start-mcp-server --help
# After home-switch:
grep -A2 excluded_tools ~/.serena/serena_config.yml
```

- Docs: [oraios.github.io/serena](https://oraios.github.io/serena/)
- Donate: [github.com/sponsors/oraios](https://github.com/sponsors/oraios)

### Context7

[Context7](https://github.com/upstash/context7) is a remote MCP for up-to-date library docs. Home Manager upserts `https://mcp.context7.com/mcp` into `~/.cursor/mcp.json`. No API key is asked at copy time.

- Docs: [github.com/upstash/context7](https://github.com/upstash/context7)
- Donate: [github.com/sponsors/upstash](https://github.com/sponsors/upstash)

### git-conflict-mcp

[git-conflict-mcp](https://github.com/mattyatea/git-conflict-mcp) helps agents and humans resolve merge conflicts (optional WebUI). Home Manager installs the npm pin from the non-Nix catalog (mise) and upserts it into `~/.cursor/mcp.json` when `cursor.llmContext.enable` is on. You can still run `npx -y git-conflict-mcp` ad hoc; the catalog pin is what `home-switch` / mise install. Pin `1.12.5` has no npm provenance (unlike `1.11.10`) and a low download count; the catalog sets narrow aube options (`trust_policy_excludes`, `allow_builds`, `allow_low_downloads`) so non-interactive `mise install` does not abort with “user aborted”.

- Docs: [mattyatea/git-conflict-mcp](https://github.com/mattyatea/git-conflict-mcp)

### git-rebase-mcp

[git-rebase-mcp](https://github.com/aaron-riact/git-rebase-mcp) lets an agent drive rebases (and cherry-pick/merge/revert conflicts) with safety checks (refuse bad amends, preflight, proceed/abort). Installed from GitHub via mise `pipx:` (uv tool install under the hood); pin is the default-branch commit SHA. Upserted into `~/.cursor/mcp.json` with the other catalog MCPs.

- Docs: [aaron-riact/git-rebase-mcp](https://github.com/aaron-riact/git-rebase-mcp)

### Brave Search

Optional. Set a [Brave Search API](https://brave.com/search/api/) key in SecretSpec / gitignored `.env`. Empty skips the MCP. Home Manager upserts the official `@brave/brave-search-mcp-server` pin from the non-Nix catalog (mise `npm`, STDIO) when `BRAVE_API_KEY` is set. `mcp-secrets-watch` re-upserts when the key changes.

- Docs: [Brave Search API](https://brave.com/search/api/) · [brave-search-mcp-server](https://github.com/brave/brave-search-mcp-server)

### Firecrawl

Optional. Set a [Firecrawl](https://www.firecrawl.dev/) API key (free tier) in SecretSpec / gitignored `.env`. Empty skips the MCP unless you set `FIRECRAWL_MCP_PROFILE=slim` for keyless-only. Same path as Brave.

**Default when enabled (slim):** Home Manager upserts the hosted keyless MCP URL `https://mcp.firecrawl.dev/v2/mcp` — three tools (`firecrawl_scrape`, `firecrawl_search`, `firecrawl_parse`), low schema tax. The API key is **not** written into `~/.cursor/mcp.json` (Bearer auth on that URL unlocks the full tool surface).

**Full profile (opt-in):** set `FIRECRAWL_MCP_PROFILE=full` with `FIRECRAWL_API_KEY` to use the local `firecrawl-mcp` pin from the non-Nix catalog (mise `npm`) — the large ~25+ tool surface. `mcp-secrets-watch` re-upserts when the key or profile changes.

- Docs: [Firecrawl](https://www.firecrawl.dev/) · [MCP](https://docs.firecrawl.dev/mcp-server) · [Keyless / slim](https://docs.firecrawl.dev/mcp-server/keyless)

### Neovim and nano

User-global [Neovim](https://neovim.io/) via [nixvim](https://github.com/nix-community/nixvim) (`programs.nixvim`) and [nano](https://www.nano-editor.org/) with bundled syntax files.

The `neovim` tool (`tools/ide/neovim.nix`, category `ide`) enables a minimal nixvim config (no plugins; Ruby/Python providers off). The flake input `nixvim` is imported on the `home-cli` Den aspect; extend with nixvim modules in `home.local.nix` or compose the thin preset `ide.neovim`. The hub preset `ide` still enables Cursor, VS Code, and Neovim together.

```bash
nvim --version
```

- Neovim: [neovim.io](https://neovim.io/) · Donate: [neovim.io/sponsors](https://neovim.io/sponsors/)
- nixvim: [nix-community/nixvim](https://github.com/nix-community/nixvim) · [docs](https://nix-community.github.io/nixvim/)
- nano: [nano-editor.org](https://www.nano-editor.org/)

## Quality and release

### treefmt and prek

Formatters and file linters are first-class under `linters.*` (see [Hooks](hooks.md)) and run through [devenv’s treefmt integration](https://devenv.sh/integrations/treefmt/). [prek](https://prek.j178.dev/) runs the residual git-hooks (`commit-msg`, secrets, hygiene) plus one `treefmt` hook. devenv generates the config; do not commit a hand-edited `.pre-commit-config.yaml`. `reference-transaction` is installed separately so `git tag` is gated.

```bash
treefmt                 # format / lint treefmt-backed programs
treefmt --ci --verbose  # check mode (fail on change; verbose logs)
prek run --all-files    # treefmt + residual prek
```

- treefmt: [devenv.sh/integrations/treefmt](https://devenv.sh/integrations/treefmt/)
- prek: [prek.j178.dev](https://prek.j178.dev/)

### commitlint and semantic-release

Subjects must be [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, `ci:`, `test:`, `chore:`). [commitlint](https://commitlint.js.org/) is the `commit-msg` hook (`commitlint.config.mjs`). On push to `master`/`main`, [semantic-release](https://semantic-release.gitbook.io/semantic-release/) (user-global CLI, CI uses `.releaserc.json`) versions and publishes a GitHub Release. Those tags are what consumers pin as `devenv-stdlib` once releases exist.

- Conventional Commits: [conventionalcommits.org](https://www.conventionalcommits.org/)
- commitlint: [commitlint.js.org](https://commitlint.js.org/)
- semantic-release: [handbook](https://semantic-release.gitbook.io/semantic-release/)

### Formatters, linters, and secrets

Always-on via `linters.*` → treefmt: [nixfmt](https://github.com/NixOS/nixfmt), [statix](https://github.com/oppiliappan/statix), [deadnix](https://github.com/astro/deadnix), [ShellCheck](https://www.shellcheck.net/), [typos](https://github.com/crate-ci/typos), [actionlint](https://github.com/rhysd/actionlint), [yamlfmt](https://github.com/google/yamlfmt), [Taplo](https://taplo.tamasfe.dev/) format. Residual prek: [proselint](https://github.com/amperser/proselint), [lychee](https://lychee.cli.rs/) (off by default), `check-json` / `check-toml` / `taplo-lint`, hygiene fixers, [Gitleaks](https://gitleaks.io/), commitlint. Language formatters (rustfmt, ruff, prettier, gofmt) follow `languages.*` and also land on treefmt; clippy / golangci-lint / typecheckers stay on prek. Taplo is also user-global via Home Manager (`home/taplo.nix`).

- nixfmt: [NixOS/nixfmt](https://github.com/NixOS/nixfmt)
- ShellCheck: [shellcheck.net](https://www.shellcheck.net/)
- Gitleaks: [gitleaks.io](https://gitleaks.io/)
- lychee: [lychee.cli.rs](https://lychee.cli.rs/)

### debtmap

[debtmap](https://github.com/iepathos/debtmap) (pin in `modules/non-nix/catalog.toml` as `github:iepathos/debtmap`; Nix when promotable else project mise) runs when any of rust/python/javascript/typescript/go is on. `devenv shell` writes `.debtmap.toml` (gitignored). Override thresholds in `devenv.local.nix`.

```bash
debtmap --help
```

- Docs: [iepathos/debtmap](https://github.com/iepathos/debtmap)

### BATS and act

[BATS](https://bats-core.readthedocs.io/) is the shell test runner (`bats -r --jobs "$(nproc)" tests`; GNU `parallel` required for `--jobs`). [act](https://nektosact.com/) replays GitHub Actions locally; `test-devenv` builds `devenv-act:24.04` and runs `act workflow_call` on generated workflows. `.actrc` maps both `ubuntu-24.04` and `ubuntu-26.04` to that image. `act` is also user-global (`home/act.nix`). Local act uses the rootless Engine (`DOCKER_HOST`).

```bash
bats -r --jobs "$(nproc)" tests
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

Live site: [devenv4monorepo.github.io](https://devenv4monorepo.github.io/). Vite + React, [Spectrum](https://spectrum.adobe.com/) web components via [`@lit/react`](https://lit.dev/docs/frameworks/react/), and `react-markdown` + `remark-gfm`. Content is `docs/content/*.md` imported with `?raw`. How to edit it: [Contribution guide](#contributing).

```bash
docs-dev             # http://localhost:5173
docs-build           # docs/dist
```

- Vite: [vite.dev](https://vite.dev/)
- React: [react.dev](https://react.dev/)
- Spectrum: [spectrum.adobe.com](https://spectrum.adobe.com/)
- Lit + React: [lit.dev](https://lit.dev/docs/frameworks/react/)
