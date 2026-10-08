{
  lib,
  ...
}:
let
  mock = import ../../lib/mock-framework.nix { inherit lib; };
  devenv = import ../../../stdlib/devenv.nix { inherit lib; };
  loadLib = import ../../../stdlib/load.nix { inherit lib; };
  roots = devenv.defaultRoots mock.presets;
  rootsNamed = name: lib.filter (root: baseNameOf root == name) roots;
  discovered = name: lib.sort (a: b: a < b) (map baseNameOf (loadLib.discover (rootsNamed name)));
in
{
  # presets/ide is not a devenv language name. defaultRoots must still
  # pass that directory to the loader.
  testDefaultRootsLoadIdePresets = {
    expr = discovered "ide";
    expected = [
      "default.nix"
      "mock-ide.nix"
    ];
  };

  # declsOf imports each file the way modules/devenv.nix does, so a
  # default.nix hub whose path is the directory (ide, not ide.default)
  # must load with its sibling.
  testDefaultRootsIdeDeclarations = {
    expr =
      let
        tools = devenv.refsOfTools [ mock.tools ];
        decls = devenv.declsOf (rootsNamed "ide") tools;
      in
      lib.sort (a: b: a < b) (map (decl: decl.name) decls);
    expected = [
      "ide"
      "ide.mock-ide"
    ];
  };

  # presets/host is not a devenv language name.
  testDefaultRootsLoadHostPresets = {
    expr = discovered "host";
    expected = [ "mock-guard.nix" ];
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
    expr = discovered "terminal";
    expected = [
      "mock-provider.nix"
      "mock-quake.nix"
    ];
  };
}
