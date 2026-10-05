{ tools, ... }:
{
  path = [
    "python"
    "type"
    "mock-pyright"
  ];
  description = "Mock type-checker preset (preset taxonomy ≠ tool category).";
  tools = [ tools.python.lint.mock-pyright ];
}
