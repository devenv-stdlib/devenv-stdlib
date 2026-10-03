{ lib, ... }:
let
  # Import the loader file, not stdlib/default.nix (P0 owns that entrypoint).
  devenvLoad = import ../stdlib/devenv.nix { inherit lib; };
in
{
  imports = [
    ./packages
    ./hooks/common.nix
<<<<<<< HEAD
<<<<<<< HEAD
    # Language tool presets live under presets/<lang>/<category>/ (attrpaths
    # like python.lint.ruff). Old hook/IDE/Serena paths remain as shims and
    # must not be imported here (the loader already applies their project
    # payloads). presets/examples/ is documentation only — not loaded as defaults.
=======
<<<<<<< HEAD
    # Language tool presets live under presets/lang/<lang>/ (per-tool, not
    # megapresets). Old hook/IDE/Serena paths remain as shims and must not be
    # imported here (the loader already applies their project payloads).
    # presets/examples/ is documentation only — not loaded as defaults.
=======
    # Language hooks, IDE sync, and Serena live in presets/languages/*.nix
    # (applied below via stdlib.devenv.load). No empty compat shims for the
    # old modules/hooks or modules/ides paths — pre-release, nothing public
    # to break.
>>>>>>> 9b0e804 (chore: drop empty pre-release stdlib compat shims)
>>>>>>> 9cb15d5 (chore: drop empty pre-release stdlib compat shims)
=======
    # Language tool presets live under presets/lang/<lang>/ (per-tool, not
    # megapresets), applied below via stdlib.devenv.load. No empty compat
    # shims for the old modules/hooks or modules/ides paths — pre-release,
    # nothing public to break. presets/examples/ is documentation only.
>>>>>>> 4a400b5 (docs(stdlib): point writers at per-tool presets/lang)
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
