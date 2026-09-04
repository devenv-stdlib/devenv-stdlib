# devenv

Portable [devenv](https://devenv.sh/) configuration for a reproducible Linux development toolchain.

Clone this repository, run `./setup.sh`, then `devenv shell`. Packages, git hooks, and tests are pinned in `devenv.lock`.

## Prerequisites

- Linux (x86_64 or aarch64)
- `curl` and a user that can create `/nix` (the Nix installer typically needs `sudo` once)

## Bootstrap on a fresh machine

From the repository root, one command installs or updates Nix, devenv, and Cachix, configures the devenv binary cache as root, and builds this environment:

```bash
./setup.sh
```

The script prints a notice that it needs `sudo` for the Nix daemon, flakes (if missing), and `cachix use devenv`. It does **not** add your user to Nix `trusted-users`.

Then enter the environment:

```bash
devenv shell
```

You should see `devenv ready: <user>@<hostname>`. After that, `git`, `gh`, `jq`, `rg`, `fd`, `direnv`, `nixfmt`, `bats`, and `shellcheck` are on `PATH`.

## Everyday commands

| Command | Purpose |
| --- | --- |
| `./setup.sh` | Install or update Nix, devenv, and Cachix; build this environment |
| `devenv shell` | Enter the environment |
| `devenv test` | Build the env, check the toolchain, and run the BATS suite |
| `bats tests` | Run the `setup.sh` test suite on its own |
| `devenv update` | Refresh `devenv.lock` from `devenv.yaml` inputs |
| `devenv gc` | Delete unused environment generations |

Optional auto-activation:

- **devenv hook** (no extra tools): add `eval "$(devenv hook bash)"` to `~/.bashrc`, then `devenv allow` in this repo.
- **direnv**: install direnv, hook it in your shell, then `direnv allow` here (`.envrc` is committed).

## Layout

| Path | Role |
| --- | --- |
| `setup.sh` | One-command host bootstrap (Nix, devenv, Cachix, this environment) |
| `devenv.nix` | Shell banner, Cachix pull, tests |
| `devenv.yaml` | Inputs, module imports, CLI version pin |
| `devenv.lock` | Pinned inputs (commit this) |
| `modules/packages.nix` | Shared CLI packages |
| `modules/git-hooks.nix` | `nixfmt-rfc-style`, `statix`, `deadnix`, `shellcheck` |
| `modules/languages.nix` | Commented language examples (off by default) |
| `tests/setup.bats` | Unit tests for `setup.sh` |
| `tests/tag-hook.bats` | Tests that a failing suite really blocks `git tag` |
| `hooks/reference-transaction` | Tag guard, installed into `.git/hooks` on shell entry |
| `devenv.local.nix` | Gitignored machine-specific overrides |

## Local overrides

Copy options you do not want to share into `devenv.local.nix`:

```nix
{ ... }:
{
  # packages = [ pkgs.hello ];
}
```

## Tests

`setup.sh` is covered by [BATS](https://bats-core.readthedocs.io/) tests in `tests/`. They source `setup.sh` (its `main` guard keeps it inert when sourced) and redirect every host path it inspects through the `SETUP_*` variables, so the suite never touches the real `/nix`, the network, or `sudo`:

```bash
bats tests
```

## Tag guard

Git has no `pre-tag` hook, but `reference-transaction` runs for every ref update and aborts the transaction when it exits non-zero. `hooks/reference-transaction` uses that to run the test suite whenever a tag is created or force-moved, so a broken `setup.sh` cannot be tagged:

```console
$ git tag v1.0.0
→ running the setup.sh test suite before creating tag v1.0.0
✗ tests failed; refusing to create tag v1.0.0
fatal: in 'prepared' phase, update aborted by the reference-transaction hook
```

`enterShell` copies the hook into `.git/hooks/` on every shell entry, so entering the environment once installs it. Deleting a tag and fetching tags from a remote are not gated, and `DEVENV_SKIP_TAG_TESTS=1 git tag ...` bypasses the check.

`prek` handles the `pre-commit` hooks in `modules/git-hooks.nix` and leaves `reference-transaction` alone, so the two coexist.

## CI

| Workflow | Trigger | Runs |
| --- | --- | --- |
| `ci.yml` | Push and pull request to `main`/`master` | `devenv test` |
| `setup-tests.yml` | Changes to `setup.sh`, `tests/`, or `hooks/`, and every tag push | `bats tests` |

`setup-tests.yml` defines no branch or tag filter, which makes it run for branch pushes matching those paths and for all tag pushes — GitHub skips path filters on tag pushes.
