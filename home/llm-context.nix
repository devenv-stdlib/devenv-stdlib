{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.cursor.llmContext;
  rtkPkg = import ./rtk-pkg.nix { inherit pkgs lib; };
  githubMcpPkg = import ./github-mcp-pkg.nix { inherit pkgs lib; };
  headroomVersion = "0.37.0";
  serenaVersion = "1.7.0";
  # Official Brave package (not @modelcontextprotocol/server-brave-search).
  # 9Router's Brave Search API is a separate dashboard provider.
  braveSearchMcpVersion = "2.1.3";
  firecrawlMcpVersion = "3.24.0";
  dockerMcpImage = "mcp/docker:0.0.19";
  uvBinDir = "${config.home.homeDirectory}/.local/bin";
  python = lib.getExe pkgs.python313;
  uv = lib.getExe pkgs.uv;
  jq = lib.getExe pkgs.jq;
  rtk = lib.getExe rtkPkg;
  npx = lib.getExe' pkgs.nodejs "npx";
  # uv tools use Nix CPython; native wheels need libstdc++ from the same gcc.
  uvLibPath = lib.makeLibraryPath [
    pkgs.stdenv.cc.cc
    pkgs.zlib
  ];
  wrapUvTool =
    name:
    pkgs.writeShellScript name ''
      export LD_LIBRARY_PATH=${lib.escapeShellArg uvLibPath}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
      exec ${uvBinDir}/${name} "$@"
    '';
  headroomWrapped = wrapUvTool "headroom";
  serenaWrapped = wrapUvTool "serena";
  rtkRewrite = pkgs.writeShellScript "rtk-rewrite.sh" ''
    export RTK=${lib.escapeShellArg rtk}
    export JQ=${lib.escapeShellArg jq}
    exec ${pkgs.runtimeShell} ${./rtk-rewrite.sh}
  '';
  githubMcp = pkgs.writeShellScript "github-mcp" ''
    set -euo pipefail
    token="$(${lib.getExe pkgs.gh} auth token 2>/dev/null || true)"
    if [ -z "$token" ]; then
      echo "github-mcp: run gh auth login first" >&2
      exit 1
    fi
    export GITHUB_PERSONAL_ACCESS_TOKEN="$token"
    exec ${lib.getExe githubMcpPkg} stdio
  '';
  dockerMcp = pkgs.writeShellScript "docker-mcp" ''
    set -euo pipefail
    # shellcheck disable=SC1091
    . ${./docker-rootless.sh}
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
    exec ${npx} -y @brave/brave-search-mcp-server@${braveSearchMcpVersion}
  '';
  firecrawlMcp = pkgs.writeShellScript "firecrawl-mcp" ''
    exec ${npx} -y firecrawl-mcp@${firecrawlMcpVersion}
  '';
in
{
  options.cursor.llmContext.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.cursor.enable;
    description = ''
      Install RTK, Serena, Headroom, 9Router, and Cursor MCP servers.
      Defaults to cursor.enable.
    '';
  };

  config = lib.mkIf cfg.enable {
    # Do not set Cursor Override OpenAI Base URL: inference stays on
    # Cursor/xAI. 9Router is the local API gateway; Headroom is a sidecar
    # 9Router calls when it is up (fail-open if Headroom is down).
    # TODO: Claude Code / Cortex wrap when we support those agents

    home = {
      packages = [
        rtkPkg
        githubMcpPkg
        pkgs.jq
        pkgs.uv
        pkgs.python313
        pkgs.nodejs
      ];

      sessionVariables.UV_TOOL_BIN_DIR = uvBinDir;

      file.".cursor/rules/web-crawl-fallback.mdc".text = ''
        ---
        description: Fall back to Cursor's browser when crawl MCPs hit quota
        ---

        If Brave Search or Firecrawl returns a quota, 429, or auth error, use
        Cursor's built-in browser instead of retrying that MCP. This is
        guidance only; Cursor does not auto-switch tools.
      '';

      # First home-switch needs network. `uv tool install` with a pin is
      # idempotent on later switches.
      activation = {
        installLlmContextUvTools = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          export UV_TOOL_BIN_DIR=${lib.escapeShellArg uvBinDir}
          mkdir -p "$UV_TOOL_BIN_DIR"
          ${uv} tool install --python ${python} "headroom-ai[proxy,mcp]==${headroomVersion}"
          ${uv} tool install --python ${python} "serena-agent==${serenaVersion}"
        '';

        mergeCursorLlm = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
          export JQ=${lib.escapeShellArg jq}
          ${pkgs.runtimeShell} ${./merge-cursor-llm.sh} hooks "$HOME/.cursor/hooks.json" ${lib.escapeShellArg (toString rtkRewrite)}

          # Host-owned paths. ~/.9router is the container DATA_DIR (rootless uid).
          mkdir -p "$HOME/.config/9router"
          umask 077
          printf 'BRAVE_MCP=%s\nFIRECRAWL_MCP=%s\n' \
            ${lib.escapeShellArg (toString braveMcp)} \
            ${lib.escapeShellArg (toString firecrawlMcp)} \
            >"$HOME/.config/9router/mcp-wrappers.env"
          chmod 600 "$HOME/.config/9router/mcp-wrappers.env"

          upsert=$(mktemp)
          ${jq} -n \
            --arg serena ${lib.escapeShellArg (toString serenaWrapped)} \
            --arg headroom ${lib.escapeShellArg (toString headroomWrapped)} \
            --arg github ${lib.escapeShellArg (toString githubMcp)} \
            --arg docker ${lib.escapeShellArg (toString dockerMcp)} \
            '
              {
                serena: { command: $serena, args: ["start-mcp-server", "--context", "ide"] },
                headroom: { command: $headroom, args: ["mcp", "serve", "--proxy-url", "http://127.0.0.1:8787"] },
                context7: { url: "https://mcp.context7.com/mcp" },
                github: { command: $github },
                docker: { command: $docker }
              }
            ' >"$upsert"
          ${pkgs.runtimeShell} ${./merge-cursor-llm.sh} mcp "$HOME/.cursor/mcp.json" "$upsert"
          rm -f "$upsert"
          ${pkgs.runtimeShell} ${./merge-cursor-llm.sh} mcp-secrets "$HOME/.cursor/mcp.json" \
            ${lib.escapeShellArg (toString braveMcp)} \
            ${lib.escapeShellArg (toString firecrawlMcp)}
        '';

        # Before units start: systemd does not load .env. The start script
        # hashes INITIAL_PASSWORD so the tunnel gate sees hasPassword.
        writeNineRouterPassword = lib.hm.dag.entryBefore [ "reloadSystemd" ] ''
          mkdir -p "$HOME/.config/9router"
          passfile="$HOME/.config/9router/initial-password"
          if [ -n "''${INITIAL_PASSWORD:-}" ]; then
            umask 077
            printf '%s' "$INITIAL_PASSWORD" >"$passfile"
            chmod 600 "$passfile"
          fi
          if [ -n "''${DEVENV_ROOT:-}" ]; then
            printf '%s\n' "$DEVENV_ROOT" >"$HOME/.config/9router/devenv-root"
          fi
        '';
      };
    };

    systemd.user = {
      startServices = "sd-switch";
      services.headroom-proxy = {
        Unit = {
          Description = "Headroom sidecar (9Router saver + MCP retrieve/stats)";
        };
        Service = {
          # Do not point Headroom at 9Router (loop). 9Router calls this URL.
          # 0.0.0.0 so a rootless container can reach the host LAN IP as
          # host.docker.internal. Host livez stays http://127.0.0.1:8787.
          ExecStart = "${headroomWrapped} proxy --host 0.0.0.0 --port 8787";
          Restart = "on-failure";
          RestartSec = "5s";
        };
        Install = {
          WantedBy = [ "default.target" ];
        };
      };
      services.ninerouter = {
        Unit = {
          Description = "9Router API gateway (Headroom saver fail-open)";
          Wants = [ "headroom-proxy.service" ];
          After = [ "headroom-proxy.service" ];
        };
        Service = {
          Environment = [
            "PATH=${config.home.profileDirectory}/bin:/usr/local/bin:/usr/bin:/bin"
            "DOCKER_ROOTLESS_SH=${./docker-rootless.sh}"
            "NINEROUTER_LOOPBACK_PROXY=${./ninerouter-loopback-proxy.js}"
            "NINEROUTER_PYTHON=${lib.getExe (pkgs.python313.withPackages (p: [ p.bcrypt ]))}"
          ];
          ExecStart = "${pkgs.runtimeShell} ${./ninerouter-start.sh}";
          Restart = "on-failure";
          RestartSec = "5s";
        };
        Install = {
          WantedBy = [ "default.target" ];
        };
      };
    };
  };
}
