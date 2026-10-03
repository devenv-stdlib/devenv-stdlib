# when inherits rust category policy (languages.rust.enable or override).
{ tools, ... }: {
  path = [
    "rust"
    "lint"
    "clippy"
  ];
  description = "clippy git-hook when Rust is available.";
  tools = with tools; [ rust.lint.clippy ];
}
