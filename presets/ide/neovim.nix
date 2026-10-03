# Thin one-tool preset for Neovim (nixvim-backed). The hub presets/ide.nix still
# enables cursor + vscode + neovim together; include ide.neovim alone when you
# only want the editor tool.
{ lib, ... }:
let
  inherit (import ../../stdlib/preset.nix { inherit lib; }) mkPreset;
in
{
  imports = [
    (mkPreset {
      path = [
        "ide"
        "neovim"
      ];
      description = "Enable the Neovim tool (nix-community/nixvim Home Manager module).";
      tools = [ "neovim" ];
    })
  ];
}
