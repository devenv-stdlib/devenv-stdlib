# CodeRabbit preset: Open VSX extension + official CLI.
{ lib, ... }:
let
  inherit (import ../../stdlib/preset.nix { inherit lib; }) mkPreset;
  toolLib = import ../../stdlib/tool.nix { inherit lib; };
  loadLib = import ../../stdlib/load.nix { inherit lib; };
  tools = toolLib.refsFromSpecs (toolLib.specs (loadLib.discover [ ../../tools ]));
in
{
  imports = [
    (mkPreset {
      path = [
        "ide"
        "coderabbit"
      ];
      description = "Enable the CodeRabbit VS Code / Cursor extension (Open VSX) and CLI.";
      tools = [
        tools.ide.coderabbit
        tools.ide.coderabbit-cli
      ];
    })
  ];
}
