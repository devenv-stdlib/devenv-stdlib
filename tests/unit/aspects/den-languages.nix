# Phase 2 W2.3: remaining language hubs + JS/TS shared dedupe contract.
{
  lib,
  project,
  languageCascade,
  expectedLanguageChildren,
  ...
}:
let
  cascade = languageCascade;
  includesOf = name: cascade.${name}.includes or [ ];
  sort = xs: lib.sort (a: b: a < b) xs;
  hubShape =
    hub:
    sort (
      map (suffix: "${hub}-${suffix}") [
        "hooks"
        "ide-recs"
        "serena"
        "debtmap"
      ]
    );
in
{
  testDenLanguageHubsList = {
    expr = cascade.hubs;
    expected = [
      "python"
      "rust"
      "go"
      "javascript"
      "typescript"
    ];
  };

  testDenRustIncludesShape = {
    expr = sort (includesOf "rust");
    expected = hubShape "rust";
  };

  testDenGoIncludesShape = {
    expr = sort (includesOf "go");
    expected = hubShape "go";
  };

  testDenJavascriptIncludesShape = {
    expr = sort (includesOf "javascript");
    expected = hubShape "javascript";
  };

  testDenTypescriptIncludesShape = {
    expr = sort (includesOf "typescript");
    expected = hubShape "typescript";
  };

  testDenExpectedChildrenParity = {
    expr = builtins.mapAttrs (_: sort) expectedLanguageChildren;
    expected = builtins.mapAttrs (hub: _: hubShape hub) expectedLanguageChildren;
  };

  # JS+TS prettier / Serena typescript / IDE pack via javascriptOn.
  testDenSharedPrettierVia = {
    expr = sort cascade.shared.prettierVia;
    expected = [
      "javascript"
      "typescript"
    ];
  };

  testDenSharedSerenaTypescriptVia = {
    expr = sort cascade.shared.serenaTypescriptServerVia;
    expected = [
      "javascript"
      "typescript"
    ];
  };

  testDenSharedIdeTypescriptPackVia = {
    expr = sort cascade.shared.ideTypescriptPackVia;
    expected = [
      "javascript"
      "typescript"
    ];
  };

  testDenJavascriptOnDrivesPrettier = {
    expr = (project.languageHooks { languages.javascript.enable = true; }).prettier;
    expected = true;
  };

  testDenTypescriptOnDrivesPrettier = {
    expr = (project.languageHooks { languages.typescript.enable = true; }).prettier;
    expected = true;
  };

  testDenJavascriptSerenaUsesTypescriptServerOnce = {
    expr = project.serenaLanguageServers {
      javascript.enable = true;
      typescript.enable = true;
    };
    expected = [
      "nix"
      "typescript"
    ];
  };

  testDenJavascriptVscodeUsesTypescriptPack = {
    expr = builtins.elem "dbaeumer.vscode-eslint" (
      project.vscodeRecommendations { javascript.enable = true; }
    );
    expected = true;
  };

  testDenRustEnableDrivesDebtmap = {
    expr = project.debtmapLanguages { rust.enable = true; };
    expected = [ "rust" ];
  };

  testDenGoEnableDrivesSerena = {
    expr = builtins.elem "go" (project.serenaLanguageServers { go.enable = true; });
    expected = true;
  };
}
