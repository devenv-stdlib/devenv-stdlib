# when inherits rust category policy (languages.rust.enable or override).
_: {
  path = [
    "rust"
    "debtmap"
  ];
  description = "debtmap rust language id when Rust is available.";
  project.stdlib.lang.rust.debtmap = [ "rust" ];
}
