# when inherits rust category policy (languages.rust.enable or override).
_: {
  path = [
    "rust"
    "serena"
  ];
  description = "Serena rust language server when Rust is available.";
  project.stdlib.lang.rust.serena = [ "rust" ];
}
