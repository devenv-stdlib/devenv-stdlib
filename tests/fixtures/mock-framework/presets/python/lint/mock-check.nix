{ tools, ... }:
{
  path = [
    "python"
    "lint"
    "mock-check"
  ];
  description = "Mock preset for lang.python mock-check leaf.";
  tools = [ tools.python.mock-check ];
}
