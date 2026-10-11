# when inherits rust category policy (languages.rust.enable or override).
{ tools, ... }: {
  path = [
    "rust"
    "lint"
    "clippy"
  ];
  description = "clippy git-hook when Rust is available.";
  tools = [ tools.rust.lint.clippy ];
}
