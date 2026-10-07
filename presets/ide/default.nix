# Any-of IDE policy: B2's home-cursor rule generalised to cursor / vscode / neovim.
# Same file serves both loaders:
#   - stdlib.devenv.load passes `tools` → thin preset declaration (path `ide`)
#   - Den / evalModules import without `tools` → mkPreset module
args@{ lib, ... }:
let
  inherit (import ../../stdlib/preset.nix { inherit lib; }) mkPreset;
  toolLib = import ../../stdlib/tool.nix { inherit lib; };
  loadLib = import ../../stdlib/load.nix { inherit lib; };
  toolRefs = toolLib.refsFromSpecs (toolLib.specs (loadLib.discover [ ../../tools ]));

  spec = {
    path = [ "ide" ];
    description = "Any of Cursor, VS Code, or Neovim. Does not exclude the other IDEs.";

    # ide cardinality is any-of, so listing these does not exclude nano or each other.
    tools = [
      toolRefs.ide.cursor
      toolRefs.ide.vscode
      toolRefs.ide.neovim
    ];
  };
in
if args ? tools then
  spec
else
  {
    imports = [ (mkPreset spec) ];
  }
