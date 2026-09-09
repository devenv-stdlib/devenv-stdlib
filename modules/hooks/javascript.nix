{ lib, config, ... }:
let
  project = import ../lib/project.nix { inherit lib; };
  on = project.javascriptOn (config.languages or { });
in
{
  git-hooks.hooks.prettier = {
    enable = on;
    files = "\\.(cjs|js|jsx|mjs|ts|tsx)$";
  };
}
