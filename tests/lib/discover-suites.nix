# Additive discovery of per-tool / per-preset nix-unit and integration suites.
# A suite root is tools|presets/**/tests/{unit,integration}/default.nix.
# Colocated tests/ directories are skipped by stdlib.discover / devenv collect.
{ lib }:
rec {
  discoverUnder =
    kind: roots:
    let
      walk =
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
              else if typ != "directory" then
                [ ]
              else if name == "tests" then
                let
                  candidate = path + "/${kind}/default.nix";
                in
                if builtins.pathExists candidate then [ candidate ] else [ ]
              else
                walk path
            ) (builtins.attrNames listing.value);
    in
    lib.sort (a: b: toString a < toString b) (lib.concatMap walk roots);

  discoverUnitSuites = discoverUnder "unit";
  discoverIntegrationSuites = discoverUnder "integration";
}
