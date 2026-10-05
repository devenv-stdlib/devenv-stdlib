# Unit tests for language → PR-Metrics code-file-extensions derivation.
{ lib, ... }:
let
  inherit
    (import <devenv4monorepo/presets/ci/github_actions/pr-metrics/_code-file-extensions.nix> {
      inherit lib;
    })
    codeFileExtensions
    alwaysBase
    docsExtensions
    ;

  split = s: lib.filter (x: x != "") (lib.splitString "\n" s);

  hasAll = needles: haystack: builtins.all (n: builtins.elem n haystack) needles;
in
{
  testPrMetricsExtAlwaysBase = {
    expr = split (codeFileExtensions { });
    expected = alwaysBase;
  };

  testPrMetricsExtDocsTooling = {
    expr =
      let
        exts = split (codeFileExtensions {
          docsTooling = true;
        });
      in
      {
        hasBase = hasAll alwaysBase exts;
        hasDocs = hasAll docsExtensions exts;
        sorted = exts;
      };
    expected = {
      hasBase = true;
      hasDocs = true;
      sorted = [
        "html"
        "nix"
        "ts"
        "tsx"
        "yaml"
        "yml"
      ];
    };
  };

  testPrMetricsExtPython = {
    expr =
      let
        exts = split (codeFileExtensions {
          languages.python.enable = true;
        });
      in
      {
        hasPy = builtins.elem "py" exts;
        hasPyi = builtins.elem "pyi" exts;
        noTs = !(builtins.elem "ts" exts);
        hasNix = builtins.elem "nix" exts;
      };
    expected = {
      hasPy = true;
      hasPyi = true;
      noTs = true;
      hasNix = true;
    };
  };

  testPrMetricsExtTypescriptImpliesDocs = {
    expr =
      let
        exts = split (codeFileExtensions {
          languages.typescript.enable = true;
        });
      in
      {
        hasTs = builtins.elem "ts" exts;
        hasTsx = builtins.elem "tsx" exts;
        hasHtml = builtins.elem "html" exts;
      };
    expected = {
      hasTs = true;
      hasTsx = true;
      hasHtml = true;
    };
  };

  testPrMetricsExtRustAndGo = {
    expr =
      let
        exts = split (codeFileExtensions {
          languages = {
            rust.enable = true;
            go.enable = true;
          };
        });
      in
      {
        hasRs = builtins.elem "rs" exts;
        hasGo = builtins.elem "go" exts;
        count = builtins.length exts;
      };
    expected = {
      hasRs = true;
      hasGo = true;
      # alwaysBase (3) + rs + go
      count = 5;
    };
  };
}
