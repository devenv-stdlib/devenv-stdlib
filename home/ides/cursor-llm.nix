{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.cursor.llmContext;
  nonNix = import ../../modules/non-nix/lib.nix { inherit lib; };
  resolved = nonNix.resolve pkgs;
  entry = name: lib.findFirst (e: e.name == name) null resolved;
  mise = lib.getExe pkgs.mise;
  jq = lib.getExe pkgs.jq;
  dockerMcpImage = nonNix.imageRef "docker-mcp";

  # Nix package when promoted; otherwise prefer a mise install dir binary
  # (mise exec loads full conf.d and fails if unrelated tools lack pipx/npm).
  cliExe =
    name:
    let
      e = entry name;
      bin = if e == null then name else nonNix.binName e;
      miseKey = if e == null then null else e.mise;
      installName = if miseKey == null then null else lib.replaceStrings [ ":" "/" ] [ "-" "-" ] miseKey;
    in
    if e != null && e.via == "nix" then
      lib.getExe e.package
    else
      pkgs.writeShellScript bin ''
        set -euo pipefail
        installs="''${XDG_DATA_HOME:-$HOME/.local/share}/mise/installs"
        ${lib.optionalString (installName != null) ''
          for cand in \
            "$installs"/${lib.escapeShellArg installName}/latest/${lib.escapeShellArg bin} \
            "$installs"/${lib.escapeShellArg installName}/latest/bin/${lib.escapeShellArg bin} \
            "$installs"/${lib.escapeShellArg installName}/*/${lib.escapeShellArg bin} \
            "$installs"/${lib.escapeShellArg installName}/*/bin/${lib.escapeShellArg bin}; do
            if [ -x "$cand" ]; then
              exec "$cand" "$@"
            fi
          done
        ''}
        exec ${mise} exec -- ${bin} "$@"
      '';

  mcp = import ./mcp {
    inherit
      pkgs
      lib
      dockerMcpImage
      ;
    serena = cliExe "serena";
    headroom = cliExe "headroom";
    braveMcpBin = cliExe "brave-search-mcp";
    firecrawlMcpBin = cliExe "firecrawl-mcp";
    gitConflictMcp = cliExe "git-conflict-mcp";
    gitRebaseMcp = cliExe "git-rebase-mcp";
  };

  # Copy wrapper + merge-lib together. A lone `./merge-cursor-llm.sh` store
  # path makes dirname=/nix/store and `source …/mcp/merge-lib.sh` miss.
  mergeCursorPkg = pkgs.runCommand "merge-cursor-llm" { } ''
    mkdir -p $out/mcp
    cp ${./merge-cursor-llm.sh} $out/merge-cursor-llm.sh
    cp ${./mcp/merge-lib.sh} $out/mcp/merge-lib.sh
    chmod +x $out/merge-cursor-llm.sh
  '';
  mergeCursor = "${mergeCursorPkg}/merge-cursor-llm.sh";
  loadSecrets = ../load-secrets.sh;
  watchMcpSecrets = ../watch-mcp-secrets.sh;
  hostConfigDir = "$HOME/.config/devenv4monorepo";
in
{
  options.cursor.llmContext.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.cursor.enable;
    description = ''
      Install Serena, Headroom, Context7, Docker, git-conflict-mcp,
      git-rebase-mcp, and optional Brave/Firecrawl MCP from the shared
      home/ides/mcp catalog into ~/.cursor/mcp.json (upsert only; user-added
      servers are preserved; retired catalog keys such as github are removed).
      Also writes Ponytail and Headroom Cursor rules. Defaults to cursor.enable.
    '';
  };

  config = lib.mkIf cfg.enable {
    home = {
      packages = [
        pkgs.jq
        pkgs.curl
        pkgs.inotify-tools
      ];

      file = {
        ".cursor/rules/ponytail.mdc".text = ''
          ---
          description: Prefer short diffs and YAGNI (Ponytail)
          alwaysApply: true
          ---

          # Ponytail

          Prefer the shortest working change. Delete unused code. Do not add
          abstractions, helpers, or files the user did not ask for. Keep security
          and error handling. Standard library over new dependencies.
        '';

        ".cursor/rules/headroom-compress.mdc".source = ../../.cursor/rules/headroom-compress.mdc;

        ".cursor/rules/web-crawl-fallback.mdc".text = ''
          ---
          description: Fall back to Cursor's browser when crawl MCPs hit quota
          ---

          If Brave Search or Firecrawl returns a quota, 429, or auth error, use
          Cursor's built-in browser instead of retrying that MCP. This is
          guidance only; Cursor does not auto-switch tools.
        '';
      };

      activation = {
        mergeCursorLlm = lib.hm.dag.entryAfter [ "miseInstallNonNix" ] ''
          export JQ=${lib.escapeShellArg jq}

          # One-shot cleanup from retired RTK / 9Router Home Manager paths.
          systemctl --user disable --now ninerouter.service ninerouter-secrets-watch.service 2>/dev/null || true
          ${pkgs.runtimeShell} ${mergeCursor} hooks-remove "$HOME/.cursor/hooks.json" || true
          ${pkgs.runtimeShell} ${mergeCursor} permissions-clear-rtk \
            "$HOME/.cursor/permissions.json" "$HOME/.cursor/bin/rtk" || true
          rm -f "$HOME/.cursor/bin/rtk" "$HOME/.cursor/rules/rtk-passthrough.mdc"

          mkdir -p ${hostConfigDir}
          umask 077
          printf 'BRAVE_MCP=%s\nFIRECRAWL_MCP=%s\n' \
            ${lib.escapeShellArg (toString mcp.braveMcp)} \
            ${lib.escapeShellArg (toString mcp.firecrawlMcp)} \
            >"${hostConfigDir}/mcp-wrappers.env"
          chmod 600 "${hostConfigDir}/mcp-wrappers.env"

          ${pkgs.runtimeShell} ${mergeCursor} mcp "$HOME/.cursor/mcp.json" \
            ${lib.escapeShellArg (toString mcp.mkUpsertJson)} \
            ${lib.escapeShellArg (toString mcp.mkRemoveJson)}
          ${pkgs.runtimeShell} ${mergeCursor} mcp-secrets "$HOME/.cursor/mcp.json" \
            ${lib.escapeShellArg (toString mcp.braveMcp)} \
            ${lib.escapeShellArg (toString mcp.firecrawlMcp)}
        '';

        writeDevenvRoot = lib.hm.dag.entryBefore [ "reloadSystemd" ] ''
          mkdir -p ${hostConfigDir}
          if [ -n "''${DEVENV_ROOT:-}" ]; then
            printf '%s\n' "$DEVENV_ROOT" >"${hostConfigDir}/devenv-root"
          fi
        '';
      };
    };

    systemd.user = {
      startServices = "sd-switch";
      services.mcp-secrets-watch = {
        Unit = {
          Description = "Sync Cursor MCP keys when SecretSpec changes";
        };
        Service = {
          Environment = [
            "PATH=${config.home.profileDirectory}/bin:/usr/local/bin:/usr/bin:/bin"
            "MCP_SECRETS_LOAD_SECRETS_SH=${loadSecrets}"
            "MCP_SECRETS_MERGE_CURSOR_SH=${mergeCursor}"
          ];
          ExecStart = "${pkgs.runtimeShell} ${watchMcpSecrets} watch";
          Restart = "on-failure";
          RestartSec = "10s";
        };
        Install = {
          WantedBy = [ "default.target" ];
        };
      };
    };
  };
}
