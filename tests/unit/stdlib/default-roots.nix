{
  lib,
  ...
}:
{
  # presets/ide is not a devenv language name. defaultRoots must still
  # pass that directory to the loader, including the hub preset.
  testDefaultRootsLoadIdePresets = {
    expr =
      let
        devenv = import ../../../stdlib/devenv.nix { inherit lib; };
        loadLib = import ../../../stdlib/load.nix { inherit lib; };
        roots = devenv.defaultRoots ../../../presets;
        ideRoots = lib.filter (root: baseNameOf root == "ide") roots;
        names = map baseNameOf (loadLib.discover ideRoots);
      in
      lib.sort (a: b: a < b) names;
    expected = [
      "coderabbit.nix"
      "default.nix"
      "neovim.nix"
    ];
  };
}
