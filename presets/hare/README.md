# presets/hare

Scaffold for devenv `languages.hare` tool presets.

- Attrpaths: `hare.*` (for example `hare.lint.<tool>`)
- Category policy inherits when `languages.hare.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
