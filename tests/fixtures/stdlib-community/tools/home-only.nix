{ stdlib, ... }:
stdlib.mkTool {
  name = "home-only";
  category = "terminal";
  install = "nix";
  upgrade = "flake";
  homeManager = { };
}
