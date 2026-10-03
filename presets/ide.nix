# Any-of IDE policy: B2's home-cursor rule generalised to cursor / vscode / neovim.
{ lib, ... }:
let
  inherit (import ../stdlib/preset.nix { inherit lib; }) mkPreset;
  toolLib = import ../stdlib/tool.nix { inherit lib; };
  loadLib = import ../stdlib/load.nix { inherit lib; };
  tools = toolLib.refsFromSpecs (toolLib.specs (loadLib.discover [ ../tools ]));
in
{
  imports = [
    (mkPreset {
      path = [ "ide" ];
      description = "Any of Cursor, VS Code, or Neovim. Does not exclude the other IDEs.";

      # ide cardinality is any-of, so listing these does not exclude nano or each other.
      tools = [
        tools.ide.cursor
        tools.ide.vscode
        tools.ide.neovim
      ];
    })
  ];
}
