# Apply to a monorepo

`copier` is on PATH after `home-switch` (Home Manager) or inside `devenv shell`.

```bash
# Latest tagged release (PEP 440). Use this after CI has published tags.
copier copy --trust <template-git-url> path/to/monorepo

# This checkout, including work that is not tagged yet
copier copy --trust --vcs-ref HEAD /path/to/devenv4monorepo path/to/monorepo
```

`--trust` is required. The template runs a task that moves `consumer-flake.nix` onto `flake.nix` so the generated project pins devenv-stdlib.

Copier asks for the devenv shell name and which languages to enable (Rust, Go, Python, JavaScript, TypeScript), then min/max versions, the Rust edition when Rust is on, and the options those languages require. Each max defaults to the latest stable shipped in `includes/toolchain-latest.yml` (from [endoflife.date](https://endoflife.date), aligned so min and max differ in one component). Leave a max empty for no upper bound. Answers are written to `devenv.local.nix`.

Optional [Brave Search](https://brave.com/search/api/) and [Firecrawl](https://www.firecrawl.dev/) API keys are asked (Firecrawl has a free tier). Leave a key empty to skip that MCP (for Firecrawl, you can still enable the slim hosted MCP later with `FIRECRAWL_MCP_PROFILE=slim` in `.env`). Values go to [SecretSpec](https://devenv.sh/integrations/secretspec/). This template defaults to the dotenv provider (gitignored `.env`, CI-safe). Override with `SECRETSPEC_PROVIDER` or `devenv.local.yaml` (`keyring`, `env`, `onepassword`, …). They are **not** stored in `.copier-answers.yml`. That file keeps `brave_search` and `firecrawl` booleans. An existing destination `.env` is left in place (`_skip_if_exists`). When a Firecrawl key is set, Home Manager enables the **slim** hosted MCP by default; set `FIRECRAWL_MCP_PROFILE=full` for the local full tool surface.

Commit `.copier-answers.yml` and `devenv.local.nix` in the monorepo. Do not commit `.env`. Do not edit the answers file by hand. Then `./setup.sh` and `devenv shell`. An existing `README.md` is left in place.

## devenv-stdlib

The generated `flake.nix` depends on `github:thedrow/devenv4monorepo/<commit>`, where `<commit>` is the `_commit` Copier stored in `.copier-answers.yml`. `outputs.stdlib` and `outputs.lib` on that pin are one attrset (`mkTool`, `den.load`, `devenv.load`). `mkPreset` is `stdlib/preset.nix` on the same pin. See [Standard library](#stdlib).

`presets/omer.nix` enables the template's HM bundles by attrpath (`terminal.quake`, `terminal.alacritty-atuin`, `ide`, `ide.coderabbit`, `host.hm-only-guard`). Language **tool** presets under `presets/<lang>/<category>/` follow `languages.<lang>.enable` from `devenv.local.nix`. The generated flake loads `"${inputs.devenv-stdlib}/presets"` and `./presets`.

## User workflow

A generated monorepo is a **copy** of the template, plus your `devenv.local.nix` / `home.local.nix`. Two different “updates”:

| What you type | Who owns it | What it does |
| --- | --- | --- |
| `devenv update` | devenv CLI | Refreshes **flake inputs** in `devenv.lock` (`nixpkgs`, `git-hooks`, …). Nix-managed packages move when those inputs move. |
| `update` (or `devenv run update`) | our devenv **script** | Umbrella for this template. Same name as the CLI on purpose for humans; it is a **different program**. |

`devenv update` is compiled into the devenv binary (like `git pull`). A `scripts.update` entry in Nix cannot replace that subcommand. Do **not** alias or wrap the CLI: CI and [Hooks](#hooks) already call `devenv update git-hooks`. Inside `devenv shell`, `update` is ours; `devenv update` stays lockfile-only.

1. **Your environment** (nixpkgs-managed packages, lock inputs, extras you added):

   ```bash
   devenv shell
   update                 # our script: devenv update + update.local.sh if you wrote one
   # or, lock only:
   devenv update          # CLI: flake inputs only
   ```

   After a lock change, re-enter the shell (or `direnv reload`). If Home Manager files changed, `home-switch`.
   `update.local.sh` (gitignored) is for host-only extras. Team-required tools go in
   `modules/non-nix/catalog.local.toml` (committed; copy from root
   `catalog.local.toml.example`).
   `update` bumps those pins and installs via Nix when promotable, otherwise mise.
   Do not edit `modules/non-nix/catalog.toml` pins to “upgrade” Serena/Brave.

2. **Template-shipped tools** (Serena, Headroom, Brave/Firecrawl MCP pins, debtmap, vendored agent skills, …):

   ```bash
   copier check-update
   copier update --trust  # latest Git tag from this project
   home-switch            # if home/ changed
   devenv shell           # pick up modules/ and lock from the merge
   ```

   Those versions are owned by devenv4monorepo releases. `update` / `devenv update` in your repo will **not** rewrite them. Editing the copied pin files fights the next `copier update`.

Brave Search in Cursor is the official MCP (`@brave/brave-search-mcp-server`) when `BRAVE_API_KEY` is set. Keys are upserted into `~/.cursor/mcp.json` on `home-switch` and again when `mcp-secrets-watch` sees a SecretSpec / `.env` change. Restart Cursor after a key is added or removed.

Context compaction is the user-global Ponytail rule plus Headroom MCP (`headroom mcp serve`) — the agent must call `headroom_compress` / `retrieve` / `stats` for large blobs.

## Update an existing copy

```bash
cd path/to/monorepo
copier update --trust                 # latest Git tag
copier update --trust --vcs-ref HEAD  # template branch
copier check-update                   # report whether a newer tag exists
```

Keep the destination git working tree clean before `copier update`. Inline conflict markers are rejected by the `check-merge-conflicts` hook.
