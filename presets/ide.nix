# Any-of IDE policy: B2's home-cursor rule generalised to cursor / vscode / neovim.
{ lib, ... }:
let
  inherit (import ../stdlib/preset.nix { inherit lib; }) mkPreset;
in
{
  imports = [
    (mkPreset {
      name = "ide";
      description = "Any of Cursor, VS Code, or Neovim. Does not exclude the other IDEs.";

      # ide cardinality is any-of, so listing these does not exclude nano or each other.
      tools = [
        "cursor"
        "vscode"
        "neovim"
      ];
    })
  ];
}
