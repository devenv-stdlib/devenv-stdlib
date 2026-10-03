# Thin one-tool preset for Neovim (nixvim-backed). The hub presets/ide.nix still
# enables cursor + vscode + neovim together; include ide.neovim alone when you
# only want the editor tool.
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
        "neovim"
      ];
      description = "Enable the Neovim tool (nix-community/nixvim Home Manager module).";
      tools = [ tools.ide.neovim ];
    })
  ];
}
