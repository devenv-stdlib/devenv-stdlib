{ lib, ... }:
let
  versions = import ../../../modules/languages/versions-lib.nix { inherit lib; };
in
{
  path = [
    "rust"
    "lint"
    "rustfmt"
  ];
  description = "rustfmt git-hook and edition-aware editor args when Rust is on.";
  when = cfg: (cfg.languages.rust or { }).enable or false;
  project =
    { config, ... }:
    let
      edition = config.supported.rust.edition or null;
    in
    {
      git-hooks.hooks.rustfmt = {
        enable = true;
        args = versions.rustfmtEditionArgs edition;
      };

      stdlib.lang.rust.settings = lib.optionalAttrs (edition != null) {
        "rust-analyzer.rustfmt.extraArgs" = [
          "--edition"
          edition
        ];
      };
    };
}
