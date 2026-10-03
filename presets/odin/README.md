# presets/odin

Scaffold for devenv `languages.odin` tool presets.

- Attrpaths: `odin.*` (for example `odin.lint.<tool>`)
- Category policy inherits when `languages.odin.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
