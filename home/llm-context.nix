{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.cursor.llmContext;
  nine = config.cursor.ninerouter.enable;
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
      Install Serena, Context7, GitHub, Docker, and optional Brave/Firecrawl MCP.
      Default path also installs RTK, a Ponytail rule, and Headroom MCP.
      9Router is opt-in via cursor.ninerouter.enable.
      Defaults to cursor.enable.
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
            githubMcpPkg
            pkgs.jq
            pkgs.uv
            pkgs.python313
            pkgs.nodejs
            pkgs.curl
            pkgs.inotify-tools
          ]
          ++ lib.optionals (!nine) [ rtkPkg ];

          sessionVariables.UV_TOOL_BIN_DIR = uvBinDir;

          # First home-switch needs network. `uv tool install` with a pin is
          # idempotent on later switches.
          activation = {
            installLlmContextUvTools = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              export UV_TOOL_BIN_DIR=${lib.escapeShellArg uvBinDir}
              mkdir -p "$UV_TOOL_BIN_DIR"
              ${uv} tool install --python ${python} "serena-agent==${serenaVersion}"
              ${lib.optionalString (!nine) ''
                ${uv} tool install --python ${python} "headroom-ai[mcp]==${headroomVersion}"
              ''}
            '';

            mergeCursorLlm = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
              export JQ=${lib.escapeShellArg jq}
              ${
                if nine then
                  ''
                    ${pkgs.runtimeShell} ${./merge-cursor-llm.sh} hooks-remove "$HOME/.cursor/hooks.json"
                    rm -f "$HOME/.cursor/rules/ponytail.mdc" "$HOME/.cursor/rules/headroom-compress.mdc"
                  ''
                else
                  ''
                    ${pkgs.runtimeShell} ${./merge-cursor-llm.sh} hooks "$HOME/.cursor/hooks.json" ${lib.escapeShellArg (toString rtkRewrite)}
                  ''
              }

              # Host-owned paths. ~/.9router is the container DATA_DIR (rootless uid).
              mkdir -p "$HOME/.config/9router"
              umask 077
              printf 'BRAVE_MCP=%s\nFIRECRAWL_MCP=%s\n' \
                ${lib.escapeShellArg (toString braveMcp)} \
                ${lib.escapeShellArg (toString firecrawlMcp)} \
                >"$HOME/.config/9router/mcp-wrappers.env"
              chmod 600 "$HOME/.config/9router/mcp-wrappers.env"

              upsert=$(mktemp)
              remove=$(mktemp)
              ${
                if nine then
                  ''
                    ${jq} -n \
                      --arg serena ${lib.escapeShellArg (toString serenaWrapped)} \
                      --arg github ${lib.escapeShellArg (toString githubMcp)} \
                      --arg docker ${lib.escapeShellArg (toString dockerMcp)} \
                      '
                        {
                          serena: { command: $serena, args: ["start-mcp-server", "--context", "ide"] },
                          context7: { url: "https://mcp.context7.com/mcp" },
                          github: { command: $github },
                          docker: { command: $docker }
                        }
                      ' >"$upsert"
                    printf '%s\n' '["headroom"]' >"$remove"
                  ''
                else
                  ''
                    ${jq} -n \
                      --arg serena ${lib.escapeShellArg (toString serenaWrapped)} \
                      --arg headroom ${lib.escapeShellArg (toString headroomWrapped)} \
                      --arg github ${lib.escapeShellArg (toString githubMcp)} \
                      --arg docker ${lib.escapeShellArg (toString dockerMcp)} \
                      '
                        {
                          serena: { command: $serena, args: ["start-mcp-server", "--context", "ide"] },
                          headroom: { command: $headroom, args: ["mcp", "serve"] },
                          context7: { url: "https://mcp.context7.com/mcp" },
                          github: { command: $github },
                          docker: { command: $docker }
                        }
                      ' >"$upsert"
                    printf '%s\n' '[]' >"$remove"
                  ''
              }
              ${pkgs.runtimeShell} ${./merge-cursor-llm.sh} mcp "$HOME/.cursor/mcp.json" "$upsert" "$remove"
              rm -f "$upsert" "$remove"
              ${pkgs.runtimeShell} ${./merge-cursor-llm.sh} mcp-secrets "$HOME/.cursor/mcp.json" \
                ${lib.escapeShellArg (toString braveMcp)} \
                ${lib.escapeShellArg (toString firecrawlMcp)}
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
                "NINEROUTER_LOAD_SECRETS_SH=${./load-secrets.sh}"
                "NINEROUTER_CONFIGURE_SH=${./configure-9router.sh}"
                "NINEROUTER_MERGE_CURSOR_SH=${./merge-cursor-llm.sh}"
                "NINEROUTER_ENABLE=${if nine then "1" else "0"}"
              ];
              ExecStart = "${pkgs.runtimeShell} ${./watch-9router-secrets.sh} watch";
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

          ".cursor/rules/headroom-compress.mdc".source = ../.cursor/rules/headroom-compress.mdc;

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
              ${pkgs.runtimeShell} ${./configure-9router.sh} http://127.0.0.1:20128 http://host.docker.internal:8787 || true
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
      })
    ]
  );
}
