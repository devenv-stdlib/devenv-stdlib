# presets/nim

Scaffold for devenv `languages.nim` tool presets.

- Attrpaths: `nim.*` (for example `nim.lint.<tool>`)
- Category policy inherits when `languages.nim.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
