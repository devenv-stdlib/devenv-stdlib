# Local project tool: hooks + lang settings when enabled via thin preset.
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
    inherit ((import ../../../../lib.nix { inherit lib; })) tool;
    spec = {
      name = "mock-ruff";
      category = "lang.python.linters";
      install = {
        kind = "project";
      };
      upgrade = "none";
      project = {
        git-hooks.hooks = {
          mock-ruff.enable = true;
          mock-ruff-format.enable = true;
        };
        stdlib.lang.python.settings = {
          "[python]"."editor.defaultFormatter" = "mock.ruff";
        };
      };
    };
  in
  if args.__stdlibMeta or false then tool.meta spec else tool.applyLocal args spec
