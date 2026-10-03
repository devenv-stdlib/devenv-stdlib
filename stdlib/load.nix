# File discovery for tool and preset directories.
# den.load lowers tools/**/*.nix into Den aspects. devenv.load stays empty
# until preset project payloads exist. Missing roots still return [].
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

  # Den modules for flake.nix. Empty when no tool files are discovered.
  den =
    roots:
    let
      mkTool = import ./tool.nix { inherit lib; };
      discovered = mkTool.specs (discover roots);
      tools = lib.listToAttrs (map (d: lib.nameValuePair d.spec.name d) discovered);
      depFile =
        spec: dep:
        if tools ? ${dep} then
          tools.${dep}.file
        else
          throw "stdlib.den.load: ${spec.name} depends on unknown tool ${dep}";
    in
    if discovered == [ ] then
      [ ]
    else
      [
        (
          { den, ... }:
          {
            den.aspects = lib.mapAttrs (_: d: {
              includes = map (dep: den.aspects.${dep}) d.spec.dependsOn;
              # Import the dependency module here too, so tools.<dep>.enable
              # exists in the same Home Manager module set as the dependent tool.
              homeManager.imports = [ d.file ] ++ map (depFile d.spec) d.spec.dependsOn;
            }) tools;
          }
        )
      ];

  # Project payloads for the devenv evaluator. Empty until that lowering exists.
  devenv = _roots: [ ];
}
