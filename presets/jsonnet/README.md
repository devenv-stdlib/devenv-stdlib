# presets/jsonnet

Scaffold for devenv `languages.jsonnet` tool presets.

- Attrpaths: `jsonnet.*` (for example `jsonnet.lint.<tool>`)
- Category policy inherits when `languages.jsonnet.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
