{ tools, ... }:
{
  path = [
    "ide"
    "mock-ide"
  ];
  description = "Mock one-tool IDE preset.";
  tools = [ tools.ide.mock-ide ];
}
