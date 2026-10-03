{ lib, ... }:
let
  # Import the loader file, not stdlib/default.nix (P0 owns that entrypoint).
  devenvLoad = import ../stdlib/devenv.nix { inherit lib; };
in
{
  imports = [
    ./packages
    ./hooks/common.nix
    # Language tool presets live under presets/lang/<lang>/ (per-tool, not
    # megapresets). Old hook/IDE/Serena paths remain as shims and must not be
    # imported here (the loader already applies their project payloads).
    # presets/examples/ is documentation only — not loaded as defaults.
    ./debtmap/hooks.nix
    ./languages
    ./languages/versions.nix
    ./debtmap
    ./mise
    ./non-nix
    ./update
    ./test/devenv.nix
  ]
  ++ devenvLoad.load [ ../presets/lang ];
}
