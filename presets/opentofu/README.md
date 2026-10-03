# presets/opentofu

Scaffold for devenv `languages.opentofu` tool presets.

- Attrpaths: `opentofu.*` (for example `opentofu.lint.<tool>`)
- Category policy inherits when `languages.opentofu.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
