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
    inherit ((import ../../../lib.nix { inherit lib; })) tool;
    spec = {
      name = "mock-cpu";
      category = "profilers.cpu";
      install = {
        kind = "nix";
        attr = "hello";
      };
      upgrade = "flake";
      defaultEnable = false;
      # Global tool: tasks are available for preset export/compose (not applyLocal).
      tasks = {
        sample = {
          exec = "echo mock-cpu-sample";
        };
        report = {
          exec = "echo mock-cpu-report";
        };
      };
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
