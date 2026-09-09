{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.cursor.llmContext;
  nine = config.cursor.ninerouter.enable;
  nonNix = import ../../modules/non-nix/lib.nix { inherit lib; };
  resolved = nonNix.resolve pkgs;
  entry = name: lib.findFirst (e: e.name == name) null resolved;
  mise = lib.getExe pkgs.mise;
  jq = lib.getExe pkgs.jq;
  dockerMcpImage = nonNix.imageRef "docker-mcp";
  ninerouterImage = nonNix.imageRef "ninerouter";

  # Nix package when promoted; otherwise a thin mise shim (conf.d pins).
  cliExe =
    name:
    let
      e = entry name;
      bin = if e == null then name else nonNix.binName e;
    in
    if e != null && e.via == "nix" then
      lib.getExe e.package
    else
      pkgs.writeShellScript bin ''
        exec ${mise} exec -- ${bin} "$@"
      '';

  mcp = import ./mcp {
    inherit
      pkgs
      lib
      jq
      dockerMcpImage
      ;
    rtk = cliExe "rtk";
    serena = cliExe "serena";
    headroom = cliExe "headroom";
    githubMcpBin = cliExe "github-mcp-server";
    braveMcpBin = cliExe "brave-search-mcp";
    firecrawlMcpBin = cliExe "firecrawl-mcp";
    gitConflictMcp = cliExe "git-conflict-mcp";
    gitRebaseMcp = cliExe "git-rebase-mcp";
  };

  upsertJson = mcp.mkUpsertJson { includeHeadroom = !nine; };
  removeJson = mcp.mkRemoveJson { removeHeadroom = nine; };

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
  configureNine = ../configure-9router.sh;
  watchNine = ../watch-9router-secrets.sh;
  dockerRootless = ../docker-rootless.sh;
  nineLoopback = ../ninerouter-loopback-proxy.js;
  nineStart = ../ninerouter-start.sh;
  rtkBin = cliExe "rtk";
in
{
  options.cursor.llmContext.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.cursor.enable;
    description = ''
      Install Serena, Context7, GitHub, Docker, and optional Brave/Firecrawl MCP
      from the shared home/ides/mcp catalog into ~/.cursor/mcp.json (upsert only;
      user-added servers are preserved). Default path also installs RTK, a
      Ponytail rule, and Headroom MCP. 9Router is opt-in via
      cursor.ninerouter.enable. Defaults to cursor.enable.
    '';
  };

  options.cursor.ninerouter.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Start 9Router and point Cursor at its OpenAI-compatible gateway.
      Cursor Pro hosted models will not work while Override OpenAI Base URL is on.
    '';
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        home = {
          packages = [
            pkgs.jq
            pkgs.curl
            pkgs.inotify-tools
          ];

          activation = {
            mergeCursorLlm = lib.hm.dag.entryAfter [ "miseInstallNonNix" ] ''
              export JQ=${lib.escapeShellArg jq}
              ${
                if nine then
                  ''
                    ${pkgs.runtimeShell} ${mergeCursor} hooks-remove "$HOME/.cursor/hooks.json"
                    ${pkgs.runtimeShell} ${mergeCursor} permissions-clear-rtk \
                      "$HOME/.cursor/permissions.json" "$HOME/.cursor/bin/rtk"
                    rm -f "$HOME/.cursor/rules/ponytail.mdc" \
                      "$HOME/.cursor/rules/headroom-compress.mdc" \
                      "$HOME/.cursor/rules/rtk-passthrough.mdc"
                  ''
                else
                  ''
                    mkdir -p "$HOME/.cursor/bin"
                    ln -sfn ${lib.escapeShellArg (toString rtkBin)} "$HOME/.cursor/bin/rtk"
                    ${pkgs.runtimeShell} ${mergeCursor} permissions \
                      "$HOME/.cursor/permissions.json" "$HOME/.cursor/bin/rtk"
                    ${pkgs.runtimeShell} ${mergeCursor} hooks \
                      "$HOME/.cursor/hooks.json" ${lib.escapeShellArg (toString mcp.rtkRewrite)}
                  ''
              }

              # Host-owned paths. ~/.9router is the container DATA_DIR (rootless uid).
              mkdir -p "$HOME/.config/9router"
              umask 077
              printf 'BRAVE_MCP=%s\nFIRECRAWL_MCP=%s\n' \
                ${lib.escapeShellArg (toString mcp.braveMcp)} \
                ${lib.escapeShellArg (toString mcp.firecrawlMcp)} \
                >"$HOME/.config/9router/mcp-wrappers.env"
              chmod 600 "$HOME/.config/9router/mcp-wrappers.env"

              ${pkgs.runtimeShell} ${mergeCursor} mcp "$HOME/.cursor/mcp.json" \
                ${lib.escapeShellArg (toString upsertJson)} \
                ${lib.escapeShellArg (toString removeJson)}
              ${pkgs.runtimeShell} ${mergeCursor} mcp-secrets "$HOME/.cursor/mcp.json" \
                ${lib.escapeShellArg (toString mcp.braveMcp)} \
                ${lib.escapeShellArg (toString mcp.firecrawlMcp)}
            '';

            writeDevenvRoot = lib.hm.dag.entryBefore [ "reloadSystemd" ] ''
              mkdir -p "$HOME/.config/9router"
              if [ -n "''${DEVENV_ROOT:-}" ]; then
                printf '%s\n' "$DEVENV_ROOT" >"$HOME/.config/9router/devenv-root"
              fi
            '';
          };
        };

        systemd.user = {
          startServices = "sd-switch";
          services.ninerouter-secrets-watch = {
            Unit = {
              Description = "Sync Cursor MCP keys when SecretSpec changes";
            }
            // lib.optionalAttrs nine {
              After = [ "ninerouter.service" ];
              Wants = [ "ninerouter.service" ];
            };
            Service = {
              Environment = [
                "PATH=${config.home.profileDirectory}/bin:/usr/local/bin:/usr/bin:/bin"
                "NINEROUTER_LOAD_SECRETS_SH=${loadSecrets}"
                "NINEROUTER_CONFIGURE_SH=${configureNine}"
                "NINEROUTER_MERGE_CURSOR_SH=${mergeCursor}"
                "NINEROUTER_ENABLE=${if nine then "1" else "0"}"
              ];
              ExecStart = "${pkgs.runtimeShell} ${watchNine} watch";
              Restart = "on-failure";
              RestartSec = "10s";
            };
            Install = {
              WantedBy = [ "default.target" ];
            };
          };
        };
      }

      (lib.mkIf (!nine) {
        # Do not write Override OpenAI Base URL. Compaction is RTK + Ponytail
        # rule + official Headroom MCP (no proxy, no headroom-proxy unit).
        home.file = {
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

          ".cursor/rules/rtk-passthrough.mdc".source = ../../.cursor/rules/rtk-passthrough.mdc;

          ".cursor/rules/web-crawl-fallback.mdc".text = ''
            ---
            description: Fall back to Cursor's browser when crawl MCPs hit quota
            ---

            If Brave Search or Firecrawl returns a quota, 429, or auth error, use
            Cursor's built-in browser instead of retrying that MCP. This is
            guidance only; Cursor does not auto-switch tools.
          '';
        };
      })

      (lib.mkIf nine {
        # Cursor stores Override OpenAI Base URL in the Models GUI, not
        # settings.json. configure-9router.sh writes ~/.config/9router/cursor-api-key
        # and cursor-openai.hint. Built-in Cursor/Grok models refuse that override.
        # TODO: Claude Code / Cortex wrap when we support those agents
        home = {
          file = {
            ".config/9router/cursor-openai.hint".text = ''
              Cursor Settings → Models → Advanced (API Keys)
                Override OpenAI Base URL: http://127.0.0.1:20128/v1
                OpenAI API Key: contents of ~/.config/9router/cursor-api-key
              Then pick a 9Router model or combo (not Auto / Cursor Grok).
              Built-in Cursor Pro models fail while that override is on.
              If that key file is missing, copy a key from Dashboard → Keys (plaintext is shown only at create time).
              Turn the key toggle off (Ctrl+Shift+0) to use Pro models again.
            '';

            ".cursor/rules/web-crawl-fallback.mdc".text = ''
              ---
              description: Fall back to Cursor's browser when crawl MCPs hit quota
              ---

              Prefer a 9Router model (Override OpenAI Base URL
              http://127.0.0.1:20128/v1) so 9Router can fall back across
              Brave/Firecrawl. Auto, Cursor Grok, and Cursor WebSearch skip
              that gateway. Cursor Pro models fail while the key toggle is on.

              If Brave Search or Firecrawl returns a quota, 429, or auth error, use
              Cursor's built-in browser instead of retrying that MCP. This is
              guidance only; Cursor does not auto-switch tools.
            '';
          };

          activation = {
            writeNineRouterPassword = lib.hm.dag.entryBefore [ "reloadSystemd" ] ''
              mkdir -p "$HOME/.config/9router"
              passfile="$HOME/.config/9router/initial-password"
              if [ -n "''${INITIAL_PASSWORD:-}" ]; then
                umask 077
                printf '%s' "$INITIAL_PASSWORD" >"$passfile"
                chmod 600 "$passfile"
              fi
            '';

            configureNineRouter = lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
              export PATH=${
                lib.escapeShellArg (
                  lib.makeBinPath [
                    pkgs.curl
                    pkgs.jq
                  ]
                )
              }:$PATH
              ${pkgs.runtimeShell} ${configureNine} http://127.0.0.1:20128 http://host.docker.internal:8787 || true
              echo "9Router: set Cursor Override OpenAI Base URL — see $HOME/.config/9router/cursor-openai.hint" >&2
            '';
          };
        };

        systemd.user.services.ninerouter = {
          Unit = {
            Description = "9Router API gateway (built-in RTK + Ponytail)";
          };
          Service = {
            Environment = [
              "PATH=${config.home.profileDirectory}/bin:/usr/local/bin:/usr/bin:/bin"
              "DOCKER_ROOTLESS_SH=${dockerRootless}"
              "NINEROUTER_LOOPBACK_PROXY=${nineLoopback}"
              "NINEROUTER_PYTHON=${lib.getExe (pkgs.python313.withPackages (p: [ p.bcrypt ]))}"
              "NINEROUTER_IMAGE=${ninerouterImage}"
            ];
            ExecStart = "${pkgs.runtimeShell} ${nineStart}";
            Restart = "on-failure";
            RestartSec = "5s";
          };
          Install = {
            WantedBy = [ "default.target" ];
          };
        };
      })
    ]
  );
}
