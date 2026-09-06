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
      Install RTK, Serena, and Headroom on the user profile, merge Cursor
      hooks and MCP config, and run the Headroom proxy as a systemd user
      service. Defaults to cursor.enable.
    '';
  };

  config = lib.mkIf cfg.enable {
    # Do not set Cursor Override OpenAI Base URL: inference stays on
    # Cursor/xAI. The Headroom proxy is dashboard + MCP retrieve/stats only.
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
      };
    };

    systemd.user = {
      startServices = "sd-switch";
      services.headroom-proxy = {
        Unit = {
          Description = "Headroom proxy (dashboard and MCP retrieve/stats)";
        };
        Service = {
          ExecStart = "${headroomWrapped} proxy --host 127.0.0.1 --port 8787";
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
