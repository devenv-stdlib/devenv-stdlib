# presets/helm

Scaffold for devenv `languages.helm` tool presets.

- Attrpaths: `helm.*` (for example `helm.lint.<tool>`)
- Category policy inherits when `languages.helm.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
