{ lib, ... }:
let
  stdlib = import ../stdlib { inherit lib; };
in
{
  imports = [
    ./packages
    ./hooks/common.nix
    # Language hooks, IDE sync, and Serena moved to presets/languages/*.nix.
    # Old paths remain as shims and must not be imported here (the loader
    # already applies their project payloads).
    ./debtmap/hooks.nix
    ./languages
    ./languages/versions.nix
    ./debtmap
    ./mise
    ./non-nix
    ./update
    ./test/devenv.nix
  ]
  ++ stdlib.devenv.load [ ../presets/languages ];
}
