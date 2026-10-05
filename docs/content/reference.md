# Layout reference

Paths that land in a **generated monorepo** (Copier copy). Template-only trees (`docs/`, `includes/`, `tests/copier.bats`, `pages.yml`) are listed in the [Contribution guide](#contributing).

| Path | Role |
| --- | --- |
| `setup.sh` | One-command host bootstrap |
| `devenv.nix` | Shell banner, tests, `home-switch` (Den flake) |
| `devenv.yaml` / `devenv.lock` | Inputs and pinned lock |
| `devenv.local.nix` | Questionnaire output (`name`, `languages.*`, `supported.*`) |
| `devenv.local.nix.example` | Extra options to append (debtmap, packages, `supported.*.max`) |
| `update.local.sh` | Gitignored consumer hook; `update` runs it after local-catalog refresh |
| `catalog.local.toml.example` | Template for team tools; copy to `modules/non-nix/catalog.local.toml` |
| `modules/non-nix/catalog.local.toml` | Team tools (committed in monorepos; copy from root `.example`) |
| `.cursor/rules/update.mdc` | `update` is your lock + hook; template tools use `copier update` |
| `.cursor/rules/nix-module-split.mdc` | Split long or duplicated Nix modules under `modules/` / `home/` |
| `.cursor/rules/headroom-compress.mdc` | Call Headroom MCP only for large tool output or pastes |
| `.cursor/rules/navi-cheatsheets.mdc` | Prefer extending `cheats/*.cheat`; navi syntax; no community-sheet copies |
| `.agents/skills/` / `skills-lock.json` | 54 vendored Cursor skills (Vercel skills CLI); `README.md` there lists sources and licenses |
| `cheats/` | Repo-local [navi](https://github.com/denisidoro/navi) sheets (`NAVI_PATH` in `devenv shell`) |
| `flake.nix` | Moved from `consumer-flake.nix` after copy. Pins `devenv-stdlib` to the template `_commit` and builds Den outputs with `root` = this tree |
| `presets/omer.nix` | Names of the framework presets this template enables. Bodies stay on the `devenv-stdlib` pin |
| `modules/{aspects,den}/` + Den outputs | Den aspects / `den.homes` → `homeConfigurations.developer` (import-tree); Phase 5 `den.hosts` stubs + OS classes |
| `home/` | Home Manager modules (imported by Den aspects) |
| `home.nix` | Compat stub only — do not use `-f home.nix` |
| `home/navi.nix` | `NAVI_PATH` → pinned [denisidoro/cheats](https://github.com/denisidoro/cheats) |
| `home.local.nix` | Gitignored host overrides |
| `secretspec.toml` | Optional Brave / Firecrawl secret names and `FIRECRAWL_MCP_PROFILE` (values stay out of git) |
| `.env` | Gitignored dotenv; Copier writes keys when you pasted them |
| `stdlib/` | Framework import (`version`, categories, harness foundations, loaders). The same helpers are also reachable from the historical `modules/` and `home/` paths. |
| `modules/` | Languages, versions, hooks, debtmap, packages, `update` |
| `modules/languages/catalog.json` | Cycle → latest patch and EOL |
| `hooks/reference-transaction` | Tag guard, installed on `devenv shell` |
| `.github/workflows/ci.yml` | Lint (prek) first (treefmt + residual), then unit tests, integration tests, generated `test.yml`, semantic-release; ruleset name shims |
| `.github/workflows/update-lock.yml` | Weekly `devenv update git-hooks` pull request |
| `.github/workflows/test.yml` | Written by devenv on `enterShell`; **commit** this file |
| `.devcontainer/devcontainer.json` | Written when `devcontainer.enable`; **commit** for Codespaces / Dev Containers |

An existing destination `README.md` is left in place. This documentation site is not copied into the monorepo; use [devenv4monorepo.github.io](https://devenv4monorepo.github.io/).

`stdlib/`, `packaging/`, the publisher `flake.nix`, and `flake.lock` are template-only. The consumer flake reads the framework from the `devenv-stdlib` input. Details: [Standard library](#stdlib).
