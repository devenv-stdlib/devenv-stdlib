# Local Ruff lint + format hooks and Python editor formatter wiring.
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
    tool = import ../../../../stdlib/tool.nix { inherit lib; };
    spec = {
      name = "ruff";
      category = "lang.python.linters";
      install = {
        kind = "project";
      };
      upgrade = "none";
      project = {
        git-hooks.hooks = {
          ruff.enable = true;
          ruff-format.enable = true;
        };

        stdlib.lang.python.settings = {
          "[python]" = {
            "editor.defaultFormatter" = "charliermarsh.ruff";
            "editor.formatOnSave" = true;
            "editor.codeActionsOnSave" = {
              "source.fixAll.ruff" = "explicit";
              "source.organizeImports.ruff" = "explicit";
            };
          };
        };
      };
    };
  in
  if args.__stdlibMeta or false then
    tool.meta spec
  else
    tool.applyLocal args spec
