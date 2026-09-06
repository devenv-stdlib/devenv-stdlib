{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.cursor.llmContext;
  rtkPkg = import ./rtk-pkg.nix { inherit pkgs lib; };
  headroomVersion = "0.37.0";
  serenaVersion = "1.7.0";
  uvBinDir = "${config.home.homeDirectory}/.local/bin";
  python = lib.getExe pkgs.python313;
  uv = lib.getExe pkgs.uv;
  jq = lib.getExe pkgs.jq;
  rtk = lib.getExe rtkPkg;
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
in
{
  options.cursor.llmContext.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.cursor.enable;
    description = ''
      Install RTK, Serena, Headroom, and 9Router. Defaults to cursor.enable.
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
        pkgs.jq
        pkgs.uv
        pkgs.python313
      ];

      sessionVariables.UV_TOOL_BIN_DIR = uvBinDir;

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
          ${pkgs.runtimeShell} ${./merge-cursor-llm.sh} mcp "$HOME/.cursor/mcp.json" \
            ${lib.escapeShellArg (toString serenaWrapped)} \
            ${lib.escapeShellArg (toString headroomWrapped)}
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
