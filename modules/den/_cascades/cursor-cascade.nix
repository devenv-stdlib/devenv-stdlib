# Pure cascade metadata for the Phase 1 Den HM spike.
# Aspects under modules/aspects/ map these names onto den.aspects.* includes.
# cursor → cursor-extensions + cursor-llm (mcp-stack).
{
  cursor = {
    includes = [
      "cursor-extensions"
      "cursor-llm"
    ];
  };
  # CodeRabbit Open VSX extension (tools/ide/coderabbit.nix via den.load).
  cursor-extensions.includes = [ "coderabbit" ];
  # cursor-llm is the mcp-stack aspect (MCP upsert, rules, secrets watch).
  cursor-llm.includes = [ ];
}
