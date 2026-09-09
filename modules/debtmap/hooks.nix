{
  pkgs,
  lib,
  config,
  ...
}:
let
  project = import ../lib/project.nix { inherit lib; };
  nonNix = import ../non-nix/lib.nix { inherit lib; };
  debtmapEntry = nonNix.resolvedByName pkgs "debtmap";
  # binName treats missing catalog.bin as null (normalize), not e.name.
  bin =
    if debtmapEntry == null then
      "debtmap"
    else if debtmapEntry.bin != null then
      debtmapEntry.bin
    else
      debtmapEntry.name;
  miseKey = if debtmapEntry == null then null else debtmapEntry.mise;
  installName = if miseKey == null then null else lib.replaceStrings [ ":" "/" ] [ "-" "-" ] miseKey;
  # Prefer a mise install-dir binary: `mise exec` loads full conf.d and aborts
  # when unrelated pipx/npm tools fail, even if debtmap itself is installed.
  debtmapPkg =
    if debtmapEntry != null && debtmapEntry.via == "nix" then
      debtmapEntry.package
    else
      pkgs.writeShellScriptBin bin ''
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
        exec ${lib.getExe pkgs.mise} exec -- ${bin} "$@"
      '';
  languages = config.languages or { };
  on = project.debtmapLanguages languages != [ ];
in
{
  git-hooks.hooks.debtmap = {
    enable = on;
    name = "debtmap";
    description = "Analyze technical debt for enabled languages";
    package = debtmapPkg;
    entry = "${lib.getExe debtmapPkg} analyze . --no-tui --quiet";
    files = project.debtmapFiles languages;
    pass_filenames = false;
  };
}
