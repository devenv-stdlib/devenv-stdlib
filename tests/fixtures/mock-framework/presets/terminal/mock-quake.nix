# Include mock-term only (peer mock-alt left for XOR/exclude tests elsewhere).
{ tools, ... }:
{
  path = [
    "terminal"
    "mock-quake"
  ];
  description = "Mock quake-style include of mock-term.";
  tools = [ tools.terminal.mock-term ];
}
