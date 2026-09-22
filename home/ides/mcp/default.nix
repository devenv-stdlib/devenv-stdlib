# Shared MCP server catalog for IDE harnesses (Cursor today; others later).
# Builds upsert payloads and CLI wrappers. Does not write any harness config.
{
  pkgs,
  # Resolved CLI paths (store or mise shims).
  serena,
  headroom,
  braveMcpBin,
  firecrawlMcpBin,
  gitConflictMcp,
  gitRebaseMcp,
}:
let
  braveMcp = pkgs.writeShellScript "brave-search-mcp" ''
    exec ${braveMcpBin}
  '';

  firecrawlMcp = pkgs.writeShellScript "firecrawl-mcp" ''
    exec ${firecrawlMcpBin}
  '';

  # Core servers shared across harnesses. User-added mcpServers keys are
  # preserved by merge_mcp.
  mkCoreServers = {
    serena = {
      command = toString serena;
      args = [
        "start-mcp-server"
        "--context"
        "ide"
        "--open-web-dashboard"
        "false"
      ];
    };
    context7 = {
      url = "https://mcp.context7.com/mcp";
    };
    "git-conflict-mcp" = {
      command = toString gitConflictMcp;
    };
    "git-rebase-mcp" = {
      command = toString gitRebaseMcp;
    };
    headroom = {
      command = toString headroom;
      args = [
        "mcp"
        "serve"
      ];
    };
  };

  mkUpsertJson = pkgs.writeText "mcp-upsert.json" (builtins.toJSON mkCoreServers);

  # Retire previously shipped catalog keys on activation (merge never deletes
  # unknown user keys — only this explicit list).
  mkRemoveJson = pkgs.writeText "mcp-remove.json" (
    builtins.toJSON [
      "github"
      "docker"
    ]
  );
in
{
  inherit
    braveMcp
    firecrawlMcp
    mkCoreServers
    mkUpsertJson
    mkRemoveJson
    ;
}
