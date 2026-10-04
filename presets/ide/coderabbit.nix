# Thin one-tool preset for the CodeRabbit Open VSX extension.
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
      description = "Enable the CodeRabbit VS Code / Cursor extension (Open VSX).";
      tools = [ tools.ide.coderabbit ];
    })
  ];
}
