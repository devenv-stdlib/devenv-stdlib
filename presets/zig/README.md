# presets/zig

Scaffold for devenv `languages.zig` tool presets.

- Attrpaths: `zig.*` (for example `zig.lint.<tool>`)
- Category policy inherits when `languages.zig.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
