# when inherits go category policy (languages.go.enable or override).
_: {
  path = [
    "go"
    "debtmap"
  ];
  description = "debtmap go language id when Go is available.";
  project.stdlib.lang.go.debtmap = [ "go" ];
}
