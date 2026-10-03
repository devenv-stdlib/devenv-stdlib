# when inherits rust category policy (languages.rust.enable or override).
{ tools, ... }: {
  path = [
    "rust"
    "lint"
    "rustfmt"
  ];
  description = "rustfmt git-hook and edition-aware editor args when Rust is available.";
  tools = [ tools.rust.lint.rustfmt ];
}
