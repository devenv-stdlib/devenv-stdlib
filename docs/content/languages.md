# Languages and versions

Languages stay off in this template repo. Generated monorepos enable them through the Copier questionnaire (`devenv.local.nix`). That also installs matching Cursor extensions, writes this project's `.vscode` recommendations, generates `.serena/project.yml` `language_servers` for Serena (Serena starts its own LSPs, not Cursor's), and turns on that language's git hooks.

`devenv shell` writes `.serena/project.yml` (gitignored) from `languages.*`. This template keeps languages off, so the list is `[nix]` only. A generated monorepo with rust on gets `[nix, rust]`. JavaScript and TypeScript both map to Serena's `typescript` id (once). Override in `.serena/project.local.yml` (already gitignored). There is no committed stub; the file appears after the first `devenv shell`.

`copier copy` writes `name`, `languages.*`, and `supported.*`. `copier update` re-asks those questions. Add extra options from `devenv.local.nix.example` (debtmap, packages, `supported.*.max`) below the generated block.

## Version policy

Each enabled language requires `supported.<lang>.min`. Optional `max` and `unsupported` bound the range.

When min/max omit a patch (`3.12`, `22`), CI uses the latest patch of each non-EOL cycle in that range from `modules/languages/catalog.json` (refresh with `refresh-toolchain-latest`). Evaluation fails if min or max is EOL or missing from the catalog. Copier max defaults are aligned so min and max differ in at most one component (so that range can be enumerated).

When a patch is set (`1.80.0`–`1.85.0`), CI steps the one component that changes, minus `unsupported`. Set `versions` to list them explicitly when min and max differ in more than one component.

## Rust edition

Optional `supported.rust.edition` (`2015`, `2018`, `2021`, `2024`) is the workspace edition for rustfmt and rust-analyzer. Set the same value in Cargo.toml. Copier defaults to `2024` and `supported.rust.min = "1.85.0"`. Copier and devenv eval fail if min or max is older than that edition (2024 needs rustc 1.85, 2021 needs 1.56, 2018 needs 1.31).

Rust always includes `stable` and may add `beta` / `nightly`.

## Other languages

- JavaScript or TypeScript must pick at least one of `nodejs`, `bun`, or `deno`.
- Python is 3+ only, with `cpython` and/or `pypy`.
- Pinning `languages.python.version` (including the generated per-version `test.yml` matrix) needs the `nixpkgs-python` input in `devenv.yaml` (this template already includes it).
- `python.extensionToolchain` puts `cc`, `c++`, `make`, `pkg-config`, `rustc`, and `cargo` on PATH for pip/uv source builds. It does not enable `languages.c` or `languages.rust`.
- Rust channels other than `nixpkgs` (stable/beta/nightly in the matrix) need a `rust-overlay` input; add it when you enable Rust version matrices.
- `languages.typescript.enable` requires `typescript.bundler`: `vite`, `turbopack`, `rspack`, `tsup`, or `tsdown`. The bundler stays a `package.json` dependency.
