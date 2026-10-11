# presets/go

Scaffold for devenv `languages.go` tool presets.

- Attrpaths: `go.*` (for example `go.lint.<tool>`)
- Category policy inherits when `languages.go.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
