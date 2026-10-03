# when inherits go category policy (languages.go.enable or override).
{ tools, ... }: {
  path = [
    "go"
    "lint"
    "golangci-lint"
  ];
  description = "golangci-lint git-hook when Go is available.";
  tools = with tools; [ go.lint.golangci-lint ];
}
