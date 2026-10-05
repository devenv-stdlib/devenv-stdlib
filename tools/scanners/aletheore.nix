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

    # Prefer the catalog-pinned install dir (not `latest` / version globs) so a
    # newer side install cannot shadow the pin. pipx/uv layouts put the CLI under
    # `<pin>/bin/<bin>`; a same-named `<pin>/<bin>` path is often a *directory*
    # (package tree) — require a regular file so `-x` alone cannot pick it.
    # `mise exec` with @pin is the fallback.
    #
    # pipx/uv wheels (numpy) dlopen libstdc++.so.6; Nix shells lack a host
    # libstdc++ on the dynamic linker path. Prefix LD_LIBRARY_PATH with
    # stdenv.cc.cc.lib (same libgcc/libstdc++ source as build-cleaner /
    # mr-boxington extraBuildInputs) before exec.
    package =
      pkgs:
      let
        libstdcxx = lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ];
      in
      pkgs.writeShellScriptBin bin ''
        set -euo pipefail
        ${lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
          export LD_LIBRARY_PATH="${libstdcxx}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        ''}
        installs="''${XDG_DATA_HOME:-$HOME/.local/share}/mise/installs"
        for cand in \
          "$installs"/${lib.escapeShellArg installName}/${lib.escapeShellArg pin}/bin/${lib.escapeShellArg bin} \
          "$installs"/${lib.escapeShellArg installName}/${lib.escapeShellArg pin}/${lib.escapeShellArg bin}; do
          if [ -f "$cand" ] && [ -x "$cand" ]; then
            exec "$cand" "$@"
          fi
        done
        exec ${lib.getExe pkgs.mise} exec ${lib.escapeShellArg "${miseKey}@${pin}"} -- ${lib.escapeShellArg bin} "$@"
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
