{
  lib,
  inputs ? { },
  ...
}:
let
  # Import the loader file, not stdlib/default.nix (P0 owns that entrypoint).
  devenvLoad = import ../stdlib/devenv.nix {
    inherit lib;
    nix-log = inputs.nix-log or null;
  };
in
{
  imports = [
    ./packages
    ./hooks/common.nix
    # Language tool presets live under presets/<lang>/<category>/ (attrpaths
    # like python.lint.ruff), applied below via stdlib.devenv.load. No empty
    # compat shims for the old modules/hooks or modules/ides paths — pre-release,
    # nothing public to break. presets/examples/ is documentation only.
    # CI language/OS matrix strategy is presets/ci/language-matrix.nix
    # (attrpath ci.language-matrix).
    ./debtmap/hooks.nix
    ./languages
    ./debtmap
    ./mise
    ./non-nix
    ./update
    ./test/devenv.nix
  ]
  ++ devenvLoad.load (devenvLoad.defaultRoots ../presets);
}
