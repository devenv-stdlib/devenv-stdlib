# presets/r

Scaffold for devenv `languages.r` tool presets.

- Attrpaths: `r.*` (for example `r.lint.<tool>`)
- Category policy inherits when `languages.r.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
