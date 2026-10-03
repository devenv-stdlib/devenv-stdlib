# presets/pascal

Scaffold for devenv `languages.pascal` tool presets.

- Attrpaths: `pascal.*` (for example `pascal.lint.<tool>`)
- Category policy inherits when `languages.pascal.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
