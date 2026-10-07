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

  # discover only checks filenames. declsOf imports each file the way
  # modules/devenv.nix does, so a default.nix hub whose path is the directory
  # (ide, not ide.default) must load with its siblings.
  testDefaultRootsIdeDeclarations = {
    expr =
      let
        devenv = import ../../../stdlib/devenv.nix { inherit lib; };
        roots = lib.filter (root: baseNameOf root == "ide") (devenv.defaultRoots ../../../presets);
        tools = devenv.refsOfTools [ ../../../tools ];
        decls = devenv.declsOf roots tools;
      in
      lib.sort (a: b: a < b) (map (decl: decl.name) decls);
    expected = [
      "ide"
      "ide.coderabbit"
      "ide.neovim"
    ];
  };

  # presets/host is not a devenv language name.
  testDefaultRootsLoadHostPresets = {
    expr =
      let
        devenv = import ../../../stdlib/devenv.nix { inherit lib; };
        loadLib = import ../../../stdlib/load.nix { inherit lib; };
        roots = devenv.defaultRoots ../../../presets;
        hostRoots = lib.filter (root: baseNameOf root == "host") roots;
        names = map baseNameOf (loadLib.discover hostRoots);
      in
      lib.sort (a: b: a < b) names;
    expected = [ "hm-only-guard.nix" ];
  };

  testDefaultRootsHostDeclarations = {
    expr =
      let
        devenv = import ../../../stdlib/devenv.nix { inherit lib; };
        roots = lib.filter (root: baseNameOf root == "host") (devenv.defaultRoots ../../../presets);
        tools = devenv.refsOfTools [ ../../../tools ];
      in
      map (decl: {
        inherit (decl) name defaultEnable;
        active = decl.when { };
      }) (devenv.declsOf roots tools);
    expected = [
      {
        name = "host.hm-only-guard";
        defaultEnable = false;
        active = false;
      }
    ];
  };

  # presets/terminal is not a devenv language name.
  testDefaultRootsLoadTerminalPresets = {
    expr =
      let
        devenv = import ../../../stdlib/devenv.nix { inherit lib; };
        loadLib = import ../../../stdlib/load.nix { inherit lib; };
        roots = devenv.defaultRoots ../../../presets;
        terminalRoots = lib.filter (root: baseNameOf root == "terminal") roots;
        names = map baseNameOf (loadLib.discover terminalRoots);
      in
      lib.sort (a: b: a < b) names;
    expected = [
      "alacritty-atuin.nix"
      "quake.nix"
    ];
  };
}
