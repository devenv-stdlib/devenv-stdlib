# presets/deno

Scaffold for devenv `languages.deno` tool presets.

- Attrpaths: `deno.*` (for example `deno.lint.<tool>`)
- Category policy inherits when `languages.deno.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
