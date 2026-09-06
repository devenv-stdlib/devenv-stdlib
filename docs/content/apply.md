# Apply to a monorepo

`copier` is on PATH after `home-switch` (Home Manager) or inside `devenv shell`.

```bash
# Latest tagged release (PEP 440). Use this after CI has published tags.
copier copy <template-git-url> path/to/monorepo

# This checkout, including work that is not tagged yet
copier copy --vcs-ref HEAD /path/to/devenv4monorepo path/to/monorepo
```

Copier asks for the devenv shell name and which languages to enable (Rust, Go, Python, JavaScript, TypeScript), then min/max versions, the Rust edition when Rust is on, and the options those languages require. Each max defaults to the latest stable shipped in `includes/toolchain-latest.yml` (from [endoflife.date](https://endoflife.date), aligned so min and max differ in one component). Leave a max empty for no upper bound. Answers are written to `devenv.local.nix`.

It also asks for a [9Router](https://github.com/decolua/9router) dashboard password (`INITIAL_PASSWORD`) and optional [Brave Search](https://brave.com/search/api/) and [Firecrawl](https://www.firecrawl.dev/) API keys (both have a free tier). Leave a key empty to skip that MCP. Empty 9Router password keeps the image default (`123456`) until you set it in `.env`. Values go to [SecretSpec](https://devenv.sh/integrations/secretspec/). This template defaults to the dotenv provider (gitignored `.env`, CI-safe). Override with `SECRETSPEC_PROVIDER` or `devenv.local.yaml` (`keyring`, `env`, `onepassword`, …). They are **not** stored in `.copier-answers.yml`. That file keeps only `ninerouter_password`, `brave_search`, and `firecrawl` booleans. `home-switch` runs `secretspec export` (then falls back to `.env`) and copies `INITIAL_PASSWORD` to `~/.config/9router/initial-password` (mode `0600`) **before** the 9Router unit starts. The start script hashes that value into 9Router settings (the tunnel UI requires a stored hash; env-only login still counts as the default password). A hash you set in Dashboard → Settings is left alone. `~/.9router` stays the container `DATA_DIR`. An existing destination `.env` is left in place (`_skip_if_exists`).

Commit `.copier-answers.yml` and `devenv.local.nix` in the monorepo. Do not commit `.env`. Do not edit the answers file by hand. Then `./setup.sh` and `devenv shell`. An existing `README.md` is left in place.

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
   `update.local.sh` (gitignored) is the only place for *your* uv/npx tools. Do not edit `home/llm-context.nix` version strings to “upgrade” RTK/Serena/Brave.

2. **Template-shipped tools** (RTK, Serena, Headroom, 9Router image, GitHub/Docker/Brave/Firecrawl MCP pins, debtmap, …):

   ```bash
   copier check-update
   copier update          # latest Git tag from this project
   home-switch            # if home/ changed
   devenv shell           # pick up modules/ and lock from the merge
   ```

   Those versions are owned by devenv4monorepo releases. `update` / `devenv update` in your repo will **not** rewrite them. Editing the copied pin files fights the next `copier update`.

Brave Search in Cursor is the official MCP (`@brave/brave-search-mcp-server`) when `BRAVE_API_KEY` is set. The same keys are upserted into 9Router (`brave-search` / `firecrawl` connections named `devenv`) and `~/.cursor/mcp.json` on `home-switch` and again when `ninerouter-secrets-watch` sees a SecretSpec / `.env` change. Restart Cursor after a key is added or removed.

## Update an existing copy

```bash
cd path/to/monorepo
copier update                 # latest Git tag
copier update --vcs-ref HEAD  # template branch
copier check-update           # report whether a newer tag exists
```

Keep the destination git working tree clean before `copier update`. Inline conflict markers are rejected by the `check-merge-conflicts` hook.
