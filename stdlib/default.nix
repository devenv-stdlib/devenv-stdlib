# devenv-stdlib. External flakes use this attrset (flake output `stdlib`).
{ lib }:
let
  versionInfo = import ./version.nix;
  load = import ./load.nix { inherit lib; };
  categories = import ./categories.nix { inherit lib; };
in
{
  inherit (versionInfo) version apiVersion;

  project = import ./project.nix { inherit lib; };
  versions =
    {
      catalog ? { },
    }:
    import ./versions.nix { inherit lib catalog; };
  terminal = import ./terminal.nix { inherit lib; };
  debtmap = import ./debtmap.nix { inherit lib; };
  catalog = import ./catalog.nix { inherit lib; };
  ideExt =
    {
      pkgs,
      devenvExtensionSha256 ? null,
    }:
    import ./ide-ext.nix { inherit pkgs devenvExtensionSha256; };

  inherit categories;
  harness = import ./harness.nix { inherit lib categories; };
  shell = import ./shell.nix { inherit lib; };

  # P1 tool constructor. P0 does not define this.
  mkTool = import ./tool.nix { inherit lib; };

  inherit (load) discover;
  den.load = load.den;
  devenv.load = load.devenv;
}
