# File discovery for tool directories.
# den.load lowers global tools/**/*.nix into Den aspects.
# Local (project) tools are lowered by stdlib/devenv.nix — never import Den there.
# Missing roots still return [].
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
            # Colocated unit/integration suites live under tests/; never tools.
            if name == "tests" then [ ] else discoverOne path
          else if typ == "regular" && lib.hasSuffix ".nix" name then
            [ path ]
          else
            [ ]
        ) (builtins.attrNames listing.value);

  # Sorted store paths of *.nix files under each root. Skips names that
  # start with `_` (same idea as import-tree's `/_` filter) and any
  # `tests/` directory (per-tool / per-preset suites).
  discover = roots: lib.sort (a: b: toString a < toString b) (lib.concatMap discoverOne roots);

  # Den modules for flake.nix. Global tools only (homeManager payload).
  den =
    roots:
    let
      mkTool = import ./tool.nix { inherit lib; };
      discovered = mkTool.specs (discover roots);
      global = lib.filter (d: d.spec.isGlobal) discovered;
      tools = lib.listToAttrs (map (d: lib.nameValuePair d.spec.name d) global);
      depFile =
        spec: dep:
        if tools ? ${dep} then
          tools.${dep}.file
        else
          throw "stdlib.den.load: ${spec.name} depends on unknown global tool ${dep}";
    in
    if global == [ ] then
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
              # Keep path imports (not function wrappers) so the module system
              # deduplicates the same leaf across dependsOn edges.
              homeManager.imports = [ d.file ] ++ map (depFile d.spec) d.spec.dependsOn;
            }) tools;
          }
        )
      ];
}
