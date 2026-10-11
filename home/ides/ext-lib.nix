# Compat re-export. Implementation: stdlib/ide-ext.nix.
# The devenv VSIX hash stays here so includes/update/non-nix.sh can refresh
# `sha256` (it also rewrites defaultDevenvExtensionSha256 in the stdlib file).
{ pkgs }:
let
  # version from modules/non-nix/catalog.toml; sha256 refreshed with the pin.
  sha256 = "1bjmjrg13zynala76vz5vpm4ann1dic6awiv03w2l9rkby4agba7";
in
import ../../stdlib/ide-ext.nix {
  inherit pkgs;
  devenvExtensionSha256 = sha256;
}
