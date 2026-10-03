# presets/dotnet

Scaffold for devenv `languages.dotnet` tool presets.

- Attrpaths: `dotnet.*` (for example `dotnet.lint.<tool>`)
- Category policy inherits when `languages.dotnet.enable` (or category override)
- Add preset modules as `*.nix` (names must not start with `_`). Helpers may use `_*.nix`.
