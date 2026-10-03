# presets/julia

Scaffold for devenv `languages.julia` tool presets.

- Attrpaths: `julia.*` (for example `julia.lint.<tool>`)
- Category policy inherits when `languages.julia.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
