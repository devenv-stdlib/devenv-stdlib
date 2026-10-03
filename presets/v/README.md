# presets/v

Scaffold for devenv `languages.v` tool presets.

- Attrpaths: `v.*` (for example `v.lint.<tool>`)
- Category policy inherits when `languages.v.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
