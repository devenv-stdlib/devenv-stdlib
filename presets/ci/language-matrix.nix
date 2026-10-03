# Composable CI preset: owns language/OS test.yml matrix generation.
# Attrpath: ci.language-matrix — not a megapreset named "CI".
# Behavior matches the former modules/languages/versions.nix module.
_: {
  path = [
    "ci"
    "language-matrix"
  ];
  description = ''
    Generate .github/workflows/test.yml from stdlib.lang.*.ciMatrix flags and
    supported.* version policies (Ubuntu LTS runners).
  '';
  # Always available; presets.ci.language-matrix.enable can turn the writer off.
  when = _: true;
  project =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      catalogFile = ../../modules/languages/catalog.json;
      versions = import ../../modules/languages/versions-lib.nix {
        inherit lib;
        catalog =
          if builtins.pathExists catalogFile then builtins.fromJSON (builtins.readFile catalogFile) else { };
      };
      inherit
        (
          (import ../../stdlib {
            inherit lib;
            nix-log = null;
          })
        )
        log
        ;

      # CI matrix inputs (supported.* and per-language ciMatrix) come from
      # presets/<lang>/supported.nix and related tool presets.
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

      snapshot =
        log.debug' "ci.language-matrix snapshot"
          {
            inherit
              pythonOn
              rustOn
              goOn
              javascriptOn
              ;
          }
          {
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
      # Structured matrix for stdlib.report (devenv evaluator).
      stdlib.markers.ciMatrix = versions.matrixReport snapshot;

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
