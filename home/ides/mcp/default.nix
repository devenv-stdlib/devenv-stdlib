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
  # Optional: Aletheore CLI path. When null, aletheore is omitted from the upsert
  # (and removed on activation if previously present).
  # Product / paid plans: https://www.aletheore.com
  aletheore ? null,
}:
let
  inherit (pkgs) lib;

  braveMcp = pkgs.writeShellScript "brave-search-mcp" ''
    exec ${braveMcpBin}
  '';

  # Used only when FIRECRAWL_MCP_PROFILE=full. Default Firecrawl wiring is the
  # hosted keyless slim URL (see merge_cursor_mcp_secrets), not this wrapper.
  firecrawlMcp = pkgs.writeShellScript "firecrawl-mcp" ''
    exec ${firecrawlMcpBin}
  '';

  # Aletheore MCP is repo-scoped (`aletheore mcp <abs-path>`). User-global
  # ~/.cursor/mcp.json has no single project root, so resolve via the path
  # home-switch writes for this monorepo, then DEVENV_ROOT. Never fall back to
  # $PWD — Cursor may start outside the monorepo.
  aletheoreMcp =
    if aletheore == null then
      null
    else
      pkgs.writeShellScript "aletheore-mcp" ''
        set -euo pipefail
        root=""
        root_file="''${XDG_CONFIG_HOME:-$HOME/.config}/devenv4monorepo/devenv-root"
        if [ -f "$root_file" ]; then
          root=$(cat "$root_file")
        fi
        if [ -z "$root" ] || [ ! -d "$root" ]; then
          if [ -n "''${DEVENV_ROOT:-}" ] && [ -d "$DEVENV_ROOT" ]; then
            root="$DEVENV_ROOT"
          else
            echo "aletheore-mcp: no known monorepo root (run home-switch to write ~/.config/devenv4monorepo/devenv-root, or set DEVENV_ROOT)" >&2
            exit 1
          fi
        fi
        # Default effects keep evidence on-machine (no `external` upload).
        # Paid / hosted features: https://www.aletheore.com
        export ALETHEORE_MCP_ALLOW="''${ALETHEORE_MCP_ALLOW:-write,network}"
        exec ${aletheore} mcp "$root" "$@"
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
  }
  // lib.optionalAttrs (aletheoreMcp != null) {
    aletheore = {
      command = toString aletheoreMcp;
    };
  };

  mkUpsertJson = pkgs.writeText "mcp-upsert.json" (builtins.toJSON mkCoreServers);

  # Retire previously shipped catalog keys on activation (merge never deletes
  # unknown user keys — only this explicit list). When Aletheore is disabled,
  # remove a previously upserted entry so opt-out sticks after home-switch.
  mkRemoveJson = pkgs.writeText "mcp-remove.json" (
    builtins.toJSON (
      [
        "github"
        "docker"
      ]
      ++ lib.optionals (aletheoreMcp == null) [ "aletheore" ]
    )
  );
in
{
  inherit
    braveMcp
    firecrawlMcp
    aletheoreMcp
    mkCoreServers
    mkUpsertJson
    mkRemoveJson
    ;
}
