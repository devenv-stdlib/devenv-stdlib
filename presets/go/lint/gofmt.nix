# when inherits go category policy (languages.go.enable or override).
{ tools, ... }: {
  path = [
    "go"
    "lint"
    "gofmt"
  ];
  description = "gofmt git-hook when Go is available.";
  tools = with tools; [ go.lint.gofmt ];
}
