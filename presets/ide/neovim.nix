# Thin one-tool preset for Neovim (nixvim-backed). The hub presets/ide/default.nix still
# enables cursor + vscode + neovim together; include ide.neovim alone when you
# only want the editor tool.
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
      "neovim"
    ];
    description = "Enable the Neovim tool (nix-community/nixvim Home Manager module).";
    tools = [ toolRefs.ide.neovim ];
  };
in
if args ? tools then
  spec
else
  {
    imports = [ (mkPreset spec) ];
  }
