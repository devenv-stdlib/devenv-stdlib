{ project, ... }:
{
  testSerenaLanguageServersWhenLanguagesOff = {
    expr = project.serenaLanguageServers { };
    expected = [ "nix" ];
  };

  testSerenaLanguageServersRust = {
    expr = project.serenaLanguageServers { rust.enable = true; };
    expected = [
      "nix"
      "rust"
    ];
  };

  testSerenaLanguageServersJavascriptAndTypescriptOnce = {
    expr = [
      (project.serenaLanguageServers { javascript.enable = true; })
      (project.serenaLanguageServers { typescript.enable = true; })
      (project.serenaLanguageServers {
        javascript.enable = true;
        typescript.enable = true;
      })
    ];
    expected = [
      [
        "nix"
        "typescript"
      ]
      [
        "nix"
        "typescript"
      ]
      [
        "nix"
        "typescript"
      ]
    ];
  };

  testSerenaLanguageServersPythonAndGo = {
    expr = project.serenaLanguageServers {
      python.enable = true;
      go.enable = true;
    };
    expected = [
      "nix"
      "go"
      "python"
    ];
  };
}
