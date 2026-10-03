# when inherits rust category policy (languages.rust.enable or override).
_: {
  path = [
    "rust"
    "lint"
    "clippy"
  ];
  description = "clippy git-hook when Rust is available.";
  tools = [
    [
      "rust"
      "lint"
      "clippy"
    ]
  ];
}
