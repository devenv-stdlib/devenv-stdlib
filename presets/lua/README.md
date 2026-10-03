# presets/lua

Scaffold for devenv `languages.lua` tool presets.

- Attrpaths: `lua.*` (for example `lua.lint.<tool>`)
- Category policy inherits when `languages.lua.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
