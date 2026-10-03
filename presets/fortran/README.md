# presets/fortran

Scaffold for devenv `languages.fortran` tool presets.

- Attrpaths: `fortran.*` (for example `fortran.lint.<tool>`)
- Category policy inherits when `languages.fortran.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
