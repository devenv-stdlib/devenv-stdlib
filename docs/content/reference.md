# Layout reference

Paths that land in a **generated monorepo** (Copier copy). Template-only trees (`docs/`, `includes/`, `tests/copier.bats`, `pages.yml`) are listed in the [Contribution guide](#contributing).

| Path | Role |
| --- | --- |
| `setup.sh` | One-command host bootstrap |
| `devenv.nix` | Shell banner, Cachix pull, tests, `home-switch` |
| `devenv.yaml` / `devenv.lock` | Inputs and pinned lock |
| `devenv.local.nix` | Questionnaire output (`name`, `languages.*`, `supported.*`) |
| `devenv.local.nix.example` | Extra options to append (debtmap, packages, `supported.*.max`) |
| `update.local.sh` | Gitignored consumer hook; `update` runs it after `devenv update` |
| `.cursor/rules/update.mdc` | `update` is your lock + hook; template tools use `copier update` |
| `.cursor/rules/headroom-compress.mdc` | Call Headroom MCP only for large tool output or pastes |
| `.cursor/rules/rtk-passthrough.mdc` | Retry once without RTK compaction when a needed detail is missing |
| `home.nix` / `home/` | Home Manager (terminal, Cursor, user-global CLIs, rootless Docker `DOCKER_HOST`) |
| `home/copier-llm.nix` | Copier `ninerouter` → `cursor.ninerouter.enable` (default false) |
| `home.local.nix` | Gitignored host overrides |
| `secretspec.toml` | Optional Brave / Firecrawl secret names (values stay out of git) |
| `.env` | Gitignored dotenv; Copier writes keys when you pasted them |
| `modules/` | Languages, versions, hooks, debtmap, packages, `update` |
| `modules/toolchain-catalog.json` | Cycle → latest patch and EOL |
| `hooks/reference-transaction` | Tag guard, installed on `devenv shell` |
| `.github/workflows/ci.yml` | `test-devenv`, generated `test.yml`, semantic-release |
| `.github/workflows/hooks.yml` | `prek` on pull requests; failure comment; pre-commit.ci lite autofix |
| `.github/workflows/update-lock.yml` | Weekly `devenv update git-hooks` pull request |
| `.github/workflows/test.yml` | Written by devenv on `enterShell`; **commit** this file |

An existing destination `README.md` is left in place. This documentation site is not copied into the monorepo; use [devenv4monorepo.github.io](https://devenv4monorepo.github.io/).
