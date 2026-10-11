# CodeRabbit preset: Open VSX extension + official CLI.
# stdlib.devenv.load passes `tools` and reads the declaration; Den imports mkPreset.
args@{ lib, ... }:
let
  inherit (import ../../stdlib/preset.nix { inherit lib; }) mkPreset;
  toolLib = import ../../stdlib/tool.nix { inherit lib; };
  loadLib = import ../../stdlib/load.nix { inherit lib; };
  toolRefs = toolLib.refsFromSpecs (toolLib.specs (loadLib.discover [ ../../tools ]));

  spec = {
    path = [
      "ide"
      "coderabbit"
    ];
    description = "Enable the CodeRabbit VS Code / Cursor extension (Open VSX) and CLI.";
    tools = [
      toolRefs.ide.coderabbit
      toolRefs.ide.coderabbit-cli
    ];
  };
in
if args ? tools then
  spec
else
  {
    imports = [ (mkPreset spec) ];
  }
