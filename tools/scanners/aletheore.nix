# Aletheore CLI (evidence-grounded scan / MCP). Catalog pin: pipx:aletheore.
# Local devenv leaf — enabled by presets.ci.github_actions.aletheore.
# Product / paid plans: https://www.aletheore.com
args@{
  pkgs,
  lib,
  config,
  ...
}:
if false then
  { inherit pkgs config; }
else
  let
    tool = import ../../stdlib/tool.nix { inherit lib; };
    nonNix = import ../../modules/non-nix/lib.nix { inherit lib; };
    entry = nonNix.entryByName "aletheore";
    pin = if entry == null then "0.9.22" else entry.pin;
    miseKey = if entry == null then "pipx:aletheore" else entry.mise;
    bin = if entry == null then "aletheore" else nonNix.binName entry;
    installName = lib.replaceStrings [ ":" "/" ] [ "-" "-" ] miseKey;

    # Prefer a mise install-dir binary: `mise exec` loads full conf.d and can
    # abort when unrelated pipx/npm tools fail even if aletheore is installed.
    package =
      pkgs:
      pkgs.writeShellScriptBin bin ''
        set -euo pipefail
        installs="''${XDG_DATA_HOME:-$HOME/.local/share}/mise/installs"
        for cand in \
          "$installs"/${lib.escapeShellArg installName}/latest/${lib.escapeShellArg bin} \
          "$installs"/${lib.escapeShellArg installName}/latest/bin/${lib.escapeShellArg bin} \
          "$installs"/${lib.escapeShellArg installName}/*/${lib.escapeShellArg bin} \
          "$installs"/${lib.escapeShellArg installName}/*/bin/${lib.escapeShellArg bin}; do
          if [ -x "$cand" ]; then
            exec "$cand" "$@"
          fi
        done
        exec ${lib.getExe pkgs.mise} exec -- ${bin} "$@"
      '';

    spec = {
      name = "aletheore";
      category = "scanners";
      install = {
        kind = "catalog";
        name = "aletheore";
      };
      upgrade = "catalog";
      defaultEnable = false;
      project =
        {
          pkgs,
          lib,
          options,
          ...
        }:
        lib.mkMerge (
          [
            {
              packages = [ (package pkgs) ];
            }
          ]
          ++ lib.optionals (options ? tasks) [
            {
              tasks."aletheore:install" = {
                exec = ''
                  set -euo pipefail
                  export PATH=${
                    lib.escapeShellArg (
                      lib.makeBinPath [
                        pkgs.mise
                        pkgs.uv
                        pkgs.curl
                        pkgs.coreutils
                      ]
                    )
                  }:$PATH
                  export MISE_PIPX_UVX=1
                  # Pin from modules/non-nix/catalog.toml (pipx:aletheore).
                  mise install ${lib.escapeShellArg "${miseKey}@${pin}"}
                '';
                after = [ "devenv:files" ];
              };
              tasks."devenv:enterShell".after = [ "aletheore:install" ];
            }
          ]
        );
    };
  in
  if args.__stdlibMeta or false then tool.meta spec else tool.applyLocal args spec
