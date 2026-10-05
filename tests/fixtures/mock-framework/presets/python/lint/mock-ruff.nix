# Thin tool preset: enable mock-ruff when Python category policy is available.
{ tools, ... }:
{
  path = [
    "python"
    "lint"
    "mock-ruff"
  ];
  description = "Mock thin preset for python.lint.mock-ruff.";
  tools = [ tools.python.lint.mock-ruff ];
}
