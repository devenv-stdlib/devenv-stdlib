{ lib, ... }:
let
  # Import the loader file, not stdlib/default.nix (P0 owns that entrypoint).
  devenvLoad = import ../stdlib/devenv.nix { inherit lib; };
in
{
  imports = [
    ./packages
    ./hooks/common.nix
    # Language tool presets live under presets/<lang>/<category>/ (attrpaths
    # like python.lint.ruff), applied below via stdlib.devenv.load. No empty
    # compat shims for the old modules/hooks or modules/ides paths — pre-release,
    # nothing public to break. presets/examples/ is documentation only.
    ./debtmap/hooks.nix
    ./languages
    ./languages/versions.nix
    ./debtmap
    ./mise
    ./non-nix
    ./update
    ./test/devenv.nix
  ]
  ++ devenvLoad.load (devenvLoad.defaultRoots ../presets);
}
