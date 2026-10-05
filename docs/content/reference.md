# Layout reference

Paths in **this package repository** (publisher / dogfood checkout). Consumer trees pin the flake and keep a thinner local layout — see [Consume the package](#apply).

| Path | Role |
| --- | --- |
| `setup.sh` | One-command host bootstrap |
| `devenv.nix` | Shell banner, tests, `home-switch` (Den flake) |
| `devenv.yaml` / `devenv.lock` | Inputs and pinned lock |
| `devenv.local.nix` | Local `name`, `languages.*`, `supported.*` (gitignored here; commit in consumers) |
| `devenv.local.nix.example` | Extra options to append (debtmap, packages, `supported.*.max`) |
| `consumer-flake.nix.example` | Example consumer `flake.nix` that pins `devenv-stdlib` |
| `update.local.sh` | Gitignored consumer hook; `update` runs it after local-catalog refresh |
| `catalog.local.toml.example` | Template for team tools; copy to `modules/non-nix/catalog.local.toml` |
| `modules/non-nix/catalog.local.toml` | Team tools (committed in consumers; copy from root `.example`) |
| `.cursor/rules/update.mdc` | `update` refreshes local lock/catalog; framework tools move with the flake pin |

| `.cursor/rules/nix-module-split.mdc` | Split long or duplicated Nix modules under `modules/` / `home/` |
| `.cursor/rules/headroom-compress.mdc` | Call Headroom MCP only for large tool output or pastes |
| `.cursor/rules/navi-cheatsheets.mdc` | Prefer extending `cheats/*.cheat`; navi syntax; no community-sheet copies |
| `.agents/skills/` / `skills-lock.json` | 54 vendored Cursor skills (Vercel skills CLI); `README.md` there lists sources and licenses |
| `cheats/` | Repo-local [navi](https://github.com/denisidoro/navi) sheets (`NAVI_PATH` in `devenv shell`) |
| `flake.nix` | Publisher flake: exposes `stdlib` / `lib` and Den `homeConfigurations` |
| `presets/omer.nix` | Names of the framework presets this dogfood checkout enables |

| `modules/{aspects,den}/` + Den outputs | Den aspects / `den.homes` → `homeConfigurations.developer` (import-tree); Phase 5 `den.hosts` stubs + OS classes |
| `home/` | Home Manager modules (imported by Den aspects) |
| `home.nix` | Compat stub only — do not use `-f home.nix` |
| `home/navi.nix` | `NAVI_PATH` → pinned [denisidoro/cheats](https://github.com/denisidoro/cheats) |
| `home.local.nix` | Gitignored host overrides |
| `secretspec.toml` | Optional Brave / Firecrawl secret names and `FIRECRAWL_MCP_PROFILE` (values stay out of git) |
| `.env` | Gitignored dotenv for SecretSpec keys |
| `stdlib/` | Framework import (`version`, categories, harness foundations, loaders). The same helpers are also reachable from the historical `modules/` and `home/` paths. |
| `packaging/` | Shared Den flake body for publisher and consumers |

| `modules/` | Languages, versions, hooks, debtmap, packages, `update` |
| `modules/languages/catalog.json` | Cycle → latest patch and EOL |
| `hooks/reference-transaction` | Tag guard, installed on `devenv shell` |
| `.github/workflows/ci.yml` | Lint (prek) first (treefmt + residual), then unit tests, integration tests, generated `test.yml`, semantic-release |
| `.github/workflows/pr-quality.yml` | peakoss/anti-slop on `pull_request`; refresh with `ci:update-anti-slop` when the preset is enabled |
| `.github/workflows/aletheore.yml` | Aletheore evidence-grounded PR diffs on `pull_request`; refresh with `ci:update-aletheore` |
| `.github/workflows/update-lock.yml` | Weekly `devenv update git-hooks` pull request |
| `.github/workflows/test.yml` | Language matrix; refresh with `ci:update-language-matrix`; **commit** this file |

| `.devcontainer/devcontainer.json` | Written when `devcontainer.enable`; **commit** for Codespaces / Dev Containers |

Live docs: [devenv4monorepo.github.io](https://devenv4monorepo.github.io/).

Consumers read the framework from the `devenv-stdlib` input (`stdlib/`, `packaging/`, publisher `flake.nix`). Details: [Standard library](#stdlib).
