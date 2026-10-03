# presets/cplusplus

Scaffold for devenv `languages.cplusplus` tool presets.

- Attrpaths: `cplusplus.*` (for example `cplusplus.lint.<tool>`)
- Category policy inherits when `languages.cplusplus.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
