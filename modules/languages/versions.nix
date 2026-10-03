{
  pkgs,
  lib,
  config,
  ...
}:
let
  catalogFile = ./catalog.json;
  versions = import ./versions-lib.nix {
    inherit lib;
    catalog =
      if builtins.pathExists catalogFile then builtins.fromJSON (builtins.readFile catalogFile) else { };
  };

  # CI matrix inputs (supported.* options and per-language ciMatrix flags) live in
  # presets/lang/<lang>/*-supported.nix and related tool presets. Fall back to
  # languages.*.enable when this module is imported without stdlib.devenv.load.
  langOn = name: (config.languages.${name} or { }).enable or false;
  usePresets = config ? stdlib.lang;
  flag = name: (config.stdlib.lang.${name} or { }).ciMatrix or false;
  pythonOn = if usePresets then flag "python" else langOn "python";
  rustOn = if usePresets then flag "rust" else langOn "rust";
  goOn = if usePresets then flag "go" else langOn "go";
  javascriptOn =
    if usePresets then
      flag "javascript" || flag "typescript"
    else
      langOn "javascript" || langOn "typescript";

  snapshot = {
    inherit
      pythonOn
      rustOn
      goOn
      javascriptOn
      ;
    inherit (config.supported)
      python
      rust
      go
      javascript
      ;
  };

  problemList = versions.problems snapshot;

  workflowFile = lib.throwIf (problemList != [ ]) (lib.concatStringsSep "\n" problemList) (
    pkgs.writeText "test.yml" (versions.workflowText snapshot)
  );
in
{
  # supported.* option declarations moved to presets/lang/<lang>/supported.nix.
  config = {
    scripts.sync-language-versions-workflow.exec = ''
      set -euo pipefail
      dest="$DEVENV_ROOT/.github/workflows/test.yml"
      mkdir -p "$(dirname "$dest")"
      tmp="$(mktemp)"
      cp ${lib.escapeShellArg workflowFile} "$tmp"
      if ! cmp -s "$tmp" "$dest" 2>/dev/null; then
        mv "$tmp" "$dest"
        echo "wrote .github/workflows/test.yml"
      else
        rm -f "$tmp"
      fi
    '';

    enterShell = ''
      sync-language-versions-workflow
    '';
  };
}
