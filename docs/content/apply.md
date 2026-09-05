# Apply to a monorepo

`copier` is on PATH after `home-switch` (Home Manager) or inside `devenv shell`.

```bash
# Latest tagged release (PEP 440). Use this after CI has published tags.
copier copy <template-git-url> path/to/monorepo

# This checkout, including work that is not tagged yet
copier copy --vcs-ref HEAD /path/to/devenv4monorepo path/to/monorepo
```

Copier asks for the devenv shell name and which languages to enable (Rust, Go, Python, JavaScript, TypeScript), then min/max versions, the Rust edition when Rust is on, and the options those languages require. Each max defaults to the latest stable shipped in `includes/toolchain-latest.yml` (from [endoflife.date](https://endoflife.date), aligned so min and max differ in one component). Leave a max empty for no upper bound. Answers are written to `devenv.local.nix`.

Commit `.copier-answers.yml` and `devenv.local.nix` in the monorepo. Do not edit the answers file by hand. Then `./setup.sh` and `devenv shell`. An existing `README.md` is left in place.

## Update an existing copy

```bash
cd path/to/monorepo
copier update                 # latest Git tag
copier update --vcs-ref HEAD  # template branch
copier check-update           # report whether a newer tag exists
```

Keep the destination git working tree clean before `copier update`. Inline conflict markers are rejected by the `check-merge-conflicts` hook.
