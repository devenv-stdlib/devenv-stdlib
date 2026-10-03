# presets/nix

Scaffold for devenv `languages.nix` tool presets.

- Attrpaths: `nix.*` (for example `nix.lint.<tool>`)
- Category policy inherits when `languages.nix.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
