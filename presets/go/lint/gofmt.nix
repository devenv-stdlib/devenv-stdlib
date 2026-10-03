# when inherits go category policy (languages.go.enable or override).
_: {
  path = [
    "go"
    "lint"
    "gofmt"
  ];
  description = "gofmt git-hook when Go is available.";
  tools = [ "gofmt" ];
}
