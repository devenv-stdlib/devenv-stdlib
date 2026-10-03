{ lib, ... }:
let
  project = import ../../modules/lib/project.nix { inherit lib; };
  versions = import ../../modules/languages/versions-lib.nix { inherit lib; };
  versionPolicy = import ./_version-policy.nix { inherit lib; };
in
{
  name = "rust";
  description = "Rust hooks, IDE pack, Serena, debtmap, and CI matrix inputs.";
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
  project =
    { config, ... }:
    let
      edition = config.supported.rust.edition or null;
    in
    {
      git-hooks.hooks = {
        rustfmt = {
          enable = true;
          args = versions.rustfmtEditionArgs edition;
        };
        clippy.enable = true;
      };

      stdlib.lang.rust = {
        serena = [ "rust" ];
        debtmap = [ "rust" ];
        vscodeIds = project.vscodeLanguageIds.rust;
        extensionSet = "rust";
        ciMatrix = true;
        settings = {
          "[rust]" = {
            "editor.defaultFormatter" = "rust-lang.rust-analyzer";
            "editor.formatOnSave" = true;
          };
        }
        // lib.optionalAttrs (edition != null) {
          "rust-analyzer.rustfmt.extraArgs" = [
            "--edition"
            edition
          ];
        };
      };
    };
}
