# Layout reference

Paths that land in a **generated monorepo** (Copier copy). Template-only trees (`docs/`, `includes/`, `tests/copier.bats`, `pages.yml`) are listed in the [Contribution guide](#contributing).

| Path | Role |
| --- | --- |
| `setup.sh` | One-command host bootstrap |
| `devenv.nix` | Shell banner, tests, `home-switch` |
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
| `home.nix` / `home/` | Home Manager (terminal, Cursor, user-global CLIs, rootless Docker `DOCKER_HOST`) |
| `home/navi.nix` | `NAVI_PATH` → pinned [denisidoro/cheats](https://github.com/denisidoro/cheats) |
| `home.local.nix` | Gitignored host overrides |
| `secretspec.toml` | Optional Brave / Firecrawl secret names (values stay out of git) |
| `.env` | Gitignored dotenv; Copier writes keys when you pasted them |
| `modules/` | Languages, versions, hooks, debtmap, packages, `update` |
| `modules/languages/catalog.json` | Cycle → latest patch and EOL |
| `hooks/reference-transaction` | Tag guard, installed on `devenv shell` |
| `.github/workflows/ci.yml` | `test-devenv-unit`, then `test-devenv` (integration), generated `test.yml`, semantic-release |
| `.github/workflows/hooks.yml` | `prek` on pull requests; failure comment; pre-commit.ci lite autofix |
| `.github/workflows/update-lock.yml` | Weekly `devenv update git-hooks` pull request |
| `.github/workflows/test.yml` | Written by devenv on `enterShell`; **commit** this file |

An existing destination `README.md` is left in place. This documentation site is not copied into the monorepo; use [devenv4monorepo.github.io](https://devenv4monorepo.github.io/).
