# presets/swift

Scaffold for devenv `languages.swift` tool presets.

- Attrpaths: `swift.*` (for example `swift.lint.<tool>`)
- Category policy inherits when `languages.swift.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
