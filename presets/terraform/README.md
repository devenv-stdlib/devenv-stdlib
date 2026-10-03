# presets/terraform

Scaffold for devenv `languages.terraform` tool presets.

- Attrpaths: `terraform.*` (for example `terraform.lint.<tool>`)
- Category policy inherits when `languages.terraform.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
