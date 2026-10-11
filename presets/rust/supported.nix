# when inherits rust category policy (languages.rust.enable or override).
{ lib, ... }:
let
  versions = import ../../modules/languages/versions-lib.nix { inherit lib; };
  versionPolicy = import ../_shared/_version-policy.nix { inherit lib; };
  uniqueListOf = import ../_shared/unique-list.nix { inherit lib; };
in
{
  path = [
    "rust"
    "supported"
  ];
  description = "supported.rust options and CI matrix flag when Rust is available.";
  module = _: {
    options.supported.rust = lib.mkOption {
      type = lib.types.submodule {
        options = versionPolicy {
          channels = lib.mkOption {
            type = uniqueListOf (lib.types.enum versions.rustChannels);
            default = [ "stable" ];
            description = "Rust channels. stable is required; beta and nightly are optional extras. Repeated entries are kept once, in first-seen order.";
          };
          edition = lib.mkOption {
            type = lib.types.nullOr (lib.types.enum versions.rustEditions);
            default = null;
            description = ''
              Optional workspace Rust edition for rustfmt and rust-analyzer.
              Cargo.toml crates should use the same edition. Recommended defaults
              to 2024, which needs rustc 1.85+.
            '';
          };
        };
      };
      default = { };
    };
  };
  project.stdlib.lang.rust.ciMatrix = true;
}
