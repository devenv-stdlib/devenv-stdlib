# File discovery for tool and preset directories.
# den.load / devenv.load return module lists. P0 does not lower mkTool or
# mkPreset (those land in later phases), so the lists stay empty.
{ lib }:
rec {
  discoverOne =
    dir:
    if !builtins.pathExists dir then
      [ ]
    else
      let
        listing = builtins.tryEval (builtins.readDir dir);
      in
      if !listing.success then
        [ ]
      else
        lib.concatMap (
          name:
          let
            path = dir + "/${name}";
            typ = listing.value.${name};
          in
          if lib.hasPrefix "_" name then
            [ ]
          else if typ == "directory" then
            discoverOne path
          else if typ == "regular" && lib.hasSuffix ".nix" name then
            [ path ]
          else
            [ ]
        ) (builtins.attrNames listing.value);

  # Sorted store paths of *.nix files under each root. Skips names that
  # start with `_` (same idea as import-tree's `/_` filter).
  discover = roots: lib.sort (a: b: toString a < toString b) (lib.concatMap discoverOne roots);

  # Den modules for flake.nix. Empty until mkTool / mkPreset lowering exists.
  den = _roots: [ ];

  # Project payloads for the devenv evaluator. Empty until that lowering exists.
  devenv = _roots: [ ];
}
