# Shared MCP server catalog for IDE harnesses (Cursor today; others later).
# Builds upsert payloads and CLI wrappers. Does not write any harness config.
{
  pkgs,
  lib,
  # Resolved CLI paths (store or mise shims).
  serena,
  headroom,
  githubMcpBin,
  braveMcpBin,
  firecrawlMcpBin,
  dockerMcpImage,
  rtk,
  jq,
}:
let
  githubMcp = pkgs.writeShellScript "github-mcp" ''
    set -euo pipefail
    token="$(${lib.getExe pkgs.gh} auth token 2>/dev/null || true)"
    if [ -z "$token" ]; then
      echo "github-mcp: run gh auth login first" >&2
      exit 1
    fi
    export GITHUB_PERSONAL_ACCESS_TOKEN="$token"
    exec ${githubMcpBin} stdio
  '';

  dockerMcp = pkgs.writeShellScript "docker-mcp" ''
    set -euo pipefail
    # shellcheck disable=SC1091
    . ${../../docker-rootless.sh}
    docker_rootless_env
    docker="$(command -v docker || true)"
    if [ -z "$docker" ]; then
      for cand in /usr/bin/docker /usr/local/bin/docker; do
        if [ -x "$cand" ]; then
          docker=$cand
          break
        fi
      done
    fi
    if [ -z "$docker" ]; then
      echo "docker-mcp: docker is not on PATH" >&2
      exit 1
    fi
    sock=$(docker_engine_sock) || {
      echo "docker-mcp: DOCKER_HOST must be a unix socket" >&2
      exit 1
    }
    if [ ! -S "$sock" ]; then
      echo "docker-mcp: no Engine socket at $sock (rootless Docker is the default)" >&2
      exit 1
    fi
    exec "$docker" run -i --rm \
      -v "$sock:/var/run/docker.sock" \
      ${lib.escapeShellArg dockerMcpImage}
  '';

  braveMcp = pkgs.writeShellScript "brave-search-mcp" ''
    exec ${braveMcpBin}
  '';

  firecrawlMcp = pkgs.writeShellScript "firecrawl-mcp" ''
    exec ${firecrawlMcpBin}
  '';

  rtkRewrite = pkgs.writeShellScript "rtk-rewrite.sh" ''
    set -euo pipefail
    stable="$HOME/.cursor/bin/rtk"
    if [ -x "$stable" ]; then
      export RTK="$stable"
    else
      export RTK=${lib.escapeShellArg rtk}
    fi
    export JQ=${lib.escapeShellArg jq}
    exec ${pkgs.runtimeShell} ${../../rtk-rewrite.sh}
  '';

  # Core servers shared across harnesses. includeHeadroom=false drops headroom
  # from the upsert (gateway path) so the harness can remove the key.
  mkCoreServers =
    {
      includeHeadroom ? true,
    }:
    {
      serena = {
        command = toString serena;
        args = [
          "start-mcp-server"
          "--context"
          "ide"
        ];
      };
      context7 = {
        url = "https://mcp.context7.com/mcp";
      };
      github = {
        command = toString githubMcp;
      };
      docker = {
        command = toString dockerMcp;
      };
    }
    // lib.optionalAttrs includeHeadroom {
      headroom = {
        command = toString headroom;
        args = [
          "mcp"
          "serve"
        ];
      };
    };

  mkUpsertJson =
    {
      includeHeadroom ? true,
    }:
    pkgs.writeText "mcp-upsert.json" (
      builtins.toJSON (mkCoreServers {
        inherit includeHeadroom;
      })
    );

  mkRemoveJson =
    {
      removeHeadroom ? false,
    }:
    pkgs.writeText "mcp-remove.json" (builtins.toJSON (lib.optionals removeHeadroom [ "headroom" ]));
in
{
  inherit
    githubMcp
    dockerMcp
    braveMcp
    firecrawlMcp
    rtkRewrite
    mkCoreServers
    mkUpsertJson
    mkRemoveJson
    ;
}
