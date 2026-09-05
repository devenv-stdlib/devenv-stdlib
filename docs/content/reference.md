# Layout reference

Paths that land in a **generated monorepo** (Copier copy). Template-only trees (`docs/`, `includes/`, `tests/copier.bats`, `pages.yml`) are listed in the [Contribution guide](#contributing).

| Path | Role |
| --- | --- |
| `setup.sh` | One-command host bootstrap |
| `devenv.nix` | Shell banner, Cachix pull, tests, `home-switch` |
| `devenv.yaml` / `devenv.lock` | Inputs and pinned lock |
| `devenv.local.nix` | Questionnaire output (`name`, `languages.*`, `supported.*`) |
| `devenv.local.nix.example` | Extra options to append (debtmap, packages, `supported.*.max`) |
| `home.nix` / `home/` | Home Manager (terminal, Cursor, user-global CLIs) |
| `home.local.nix` | Gitignored host overrides |
| `modules/` | Languages, versions, hooks, debtmap, packages |
| `modules/toolchain-catalog.json` | Cycle → latest patch and EOL |
| `hooks/reference-transaction` | Tag guard, installed on `devenv shell` |
| `.github/workflows/ci.yml` | `test-devenv`, generated `test.yml`, semantic-release |
| `.github/workflows/test.yml` | Written by devenv on `enterShell`; **commit** this file |

An existing destination `README.md` is left in place. This documentation site is not copied into the monorepo; use [devenv4monorepo.github.io](https://devenv4monorepo.github.io/).
