# when inherits go category policy (languages.go.enable or override).
_: {
  path = [
    "go"
    "serena"
  ];
  description = "Serena go language server when Go is available.";
  project.stdlib.lang.go.serena = [ "go" ];
}
