# presets/kotlin

Scaffold for devenv `languages.kotlin` tool presets.

- Attrpaths: `kotlin.*` (for example `kotlin.lint.<tool>`)
- Category policy inherits when `languages.kotlin.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
