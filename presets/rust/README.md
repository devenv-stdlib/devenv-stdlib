# presets/rust

Scaffold for devenv `languages.rust` tool presets.

- Attrpaths: `rust.*` (for example `rust.lint.<tool>`)
- Category policy inherits when `languages.rust.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
