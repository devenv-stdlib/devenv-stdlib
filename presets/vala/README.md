# presets/vala

Scaffold for devenv `languages.vala` tool presets.

- Attrpaths: `vala.*` (for example `vala.lint.<tool>`)
- Category policy inherits when `languages.vala.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
