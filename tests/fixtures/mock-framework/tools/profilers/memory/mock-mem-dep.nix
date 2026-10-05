# Depends on mock-mem to exercise dependsOn in discover/meta.
args@{
  pkgs,
  lib,
  config,
  ...
}:
if false then
  { inherit pkgs config; }
else
  let
    tool = (import ../../../lib.nix { inherit lib; }).tool;
    spec = {
      name = "mock-mem-dep";
      category = "profilers.memory";
      install = {
        kind = "nix";
        attr = "hello";
      };
      upgrade = "flake";
      defaultEnable = false;
      dependsOn = [ "mock-mem" ];
    };
  in
  if args.__stdlibMeta or false then
    tool.meta spec
  else
    tool.apply args (
      spec
      // {
        homeManager = _: { };
      }
    )
