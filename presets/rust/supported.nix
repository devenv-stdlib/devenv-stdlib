{ lib, ... }:
let
  versions = import ../../modules/languages/versions-lib.nix { inherit lib; };
  versionPolicy = import ../_shared/_version-policy.nix { inherit lib; };
in
{
  path = [
    "rust"
    "supported"
  ];
  description = "supported.rust options and CI matrix flag when Rust is on.";
  when = cfg: (cfg.languages.rust or { }).enable or false;
  module = _: {
    options.supported.rust = lib.mkOption {
      type = lib.types.submodule {
        options = versionPolicy {
          channels = lib.mkOption {
            type = lib.types.listOf (lib.types.enum versions.rustChannels);
            default = [ "stable" ];
            description = "Rust channels. stable is required; beta and nightly are optional extras.";
          };
          edition = lib.mkOption {
            type = lib.types.nullOr (lib.types.enum versions.rustEditions);
            default = null;
            description = ''
              Optional workspace Rust edition for rustfmt and rust-analyzer.
              Cargo.toml crates should use the same edition. Copier defaults
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
