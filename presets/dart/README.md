# presets/dart

Scaffold for devenv `languages.dart` tool presets.

- Attrpaths: `dart.*` (for example `dart.lint.<tool>`)
- Category policy inherits when `languages.dart.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
