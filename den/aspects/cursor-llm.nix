# Feature aspect: Cursor LLM / MCP stack (mcp-stack).
# Imperative merge scripts + SecretSpec watch stay outside Den; this only composes HM modules.
{ den, ... }:
let
  cascade = import ../cursor-cascade.nix;
in
{
  den.aspects.cursor-llm = {
    includes = map (name: den.aspects.${name}) cascade.cursor-llm.includes;

    homeManager = {
      imports = [
        ../../home/ides/cursor-llm.nix
        # cursor-llm activation runs after miseInstallNonNix.
        ../../home/mise.nix
      ];
      cursor.enable = true;
      cursor.llmContext.enable = true;
    };
  };
}
