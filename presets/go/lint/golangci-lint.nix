# when inherits go category policy (languages.go.enable or override).
_: {
  path = [
    "go"
    "lint"
    "golangci-lint"
  ];
  description = "golangci-lint git-hook when Go is available.";
  tools = [ "golangci-lint" ];
}
