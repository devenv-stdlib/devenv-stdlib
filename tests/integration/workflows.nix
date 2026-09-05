# Generated workflow fixtures for actionlint and act. Runtime nix-build only.
{
  pkgs ? import <nixpkgs> { },
}:
let
  inherit (pkgs) lib;
  versions = import ../../modules/language-versions-lib.nix { inherit lib; };
  write = name: text: pkgs.writeText name text;
in
pkgs.linkFarm "workflow-fixtures" [
  {
    name = "empty.yml";
    path = write "empty.yml" (versions.workflowText { });
  }
  {
    name = "python.yml";
    path = write "python.yml" (
      versions.workflowText {
        pythonOn = true;
        python = versions.emptyPython // {
          min = "3.12";
          max = "3.13";
        };
      }
    );
  }
  {
    name = "rust.yml";
    path = write "rust.yml" (
      versions.workflowText {
        rustOn = true;
        rust = versions.emptyRust // {
          min = "1.80.0";
        };
      }
    );
  }
  {
    name = "go.yml";
    path = write "go.yml" (
      versions.workflowText {
        goOn = true;
        go = versions.emptyGo // {
          min = "1.22.0";
        };
      }
    );
  }
  {
    name = "javascript.yml";
    path = write "javascript.yml" (
      versions.workflowText {
        javascriptOn = true;
        javascript = versions.emptyJavascript // {
          runtimes = [ "deno" ];
          deno = versions.emptyPolicy // {
            min = "2.1.0";
          };
        };
      }
    );
  }
]
