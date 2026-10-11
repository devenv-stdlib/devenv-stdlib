# Composable CI preset: owns language/OS test.yml matrix generation.
# Attrpath: ci.github_actions.language-matrix.
# Builds a MatrixPlan (stdlib.ci.matrix) and renders via the GHA backend.
_: {
  path = [
    "ci"
    "github_actions"
    "language-matrix"
  ];
  description = ''
    Generate .github/workflows/test.yml from stdlib.lang.*.ciMatrix flags and
    supported.* version policies via stdlib.ci.matrix (Ubuntu LTS runner profiles).
  '';
  # Always available; presets.ci.github_actions.language-matrix.enable can turn
  # the writer off.
  when = _: true;
  project =
    {
      config,
      lib,
      pkgs,
      options,
      ...
    }:
    let
      catalogFile = ../../../modules/languages/catalog.json;
      versions = import ../../../modules/languages/versions-lib.nix {
        inherit lib;
        catalog =
          if builtins.pathExists catalogFile then builtins.fromJSON (builtins.readFile catalogFile) else { };
      };
      inherit
        (
          (import ../../../stdlib {
            inherit lib;
            nix-log = null;
          })
        )
        log
        ci
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
        log.debug' "ci.github_actions.language-matrix snapshot"
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

      generate = import ../../../stdlib/generate.nix { inherit lib; };
      # MatrixPlan → GHA YAML (no workflowText shim).
      matrixPlan = versions.languageMatrixPlan snapshot;
      workflowYaml = ci.backends.github_actions.render matrixPlan;

      workflowFile = lib.throwIf (problemList != [ ]) (lib.concatStringsSep "\n" problemList) (
        pkgs.writeText "test.yml" (generate.ensureTrailingNewline workflowYaml)
      );
      syncExec = generate.mkSyncFileExec {
        storePath = workflowFile;
        relPath = ".github/workflows/test.yml";
      };
    in
    lib.mkMerge [
      {
        stdlib = {
          # Structured matrix for stdlib.report (devenv evaluator).
          markers.ciMatrix = versions.languageMatrixReport snapshot;
          # Full MatrixPlan (expanded cells) for tooling / future backends.
          markers.ciMatrixPlan = matrixPlan;

          generated = [
            {
              path = ".github/workflows/test.yml";
              task = "ci:update-language-matrix";
              script = "sync-language-versions-workflow";
              source = workflowFile;
            }
          ];
        };

        scripts.sync-language-versions-workflow.exec = syncExec;
      }
      # mkIf false still defines `tasks` and breaks fixtures without that option.
      (lib.optionalAttrs (options ? tasks) {
        tasks."ci:update-language-matrix".exec = syncExec;
      })
    ];
}
