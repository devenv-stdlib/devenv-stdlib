# devenv-stdlib. External flakes use this attrset (flake output `stdlib`).
# `nix-log` is a private implementation detail for stdlib.log — callers must
# not take inputs.nix-log; use stdlib.log only.
{
  lib,
  nix-log ? null,
}:
let
  versionInfo = import ./version.nix;
  load = import ./load.nix { inherit lib; };
  categories = import ./categories.nix { inherit lib; };
  log = import ./log.nix { inherit lib nix-log; };
  report = import ./report.nix { inherit lib log; };
in
{
  inherit (versionInfo) version apiVersion;

  inherit log report;

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
  categoryPolicy = import ./category-policy.nix { inherit lib; };
  categoryWarnings = import ./category-warnings.nix { inherit lib; };
  # Flat lists of devenv languages.* / services.* ids (category scaffold source).
  devenvSupported = import ./devenv-supported.nix;
  harness = import ./harness.nix { inherit lib categories; };
  shell = import ./shell.nix { inherit lib; };

  # First-class linter catalog (treefmt vs prek backends). Options live at
  # linters.* via modules/linters — parallel to languages.*.
  linters = import ./linters.nix { inherit lib; };

  # Public tool constructor (stdlib/tool.nix).
  mkTool = import ./tool.nix { inherit lib; };
  # Non-nixpkgs release fetch helpers for install.kind = binary.
  binary = import ./binary.nix { inherit lib; };

  inherit (load) discover;
  den.load = load.den;
  # Project/local tools + presets: stdlib/devenv.nix (never Den).
  devenv.load = (import ./devenv.nix { inherit lib; }).load;
}
