# presets/ocaml

Scaffold for devenv `languages.ocaml` tool presets.

- Attrpaths: `ocaml.*` (for example `ocaml.lint.<tool>`)
- Category policy inherits when `languages.ocaml.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
