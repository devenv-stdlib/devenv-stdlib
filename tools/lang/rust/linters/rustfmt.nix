# Local rustfmt git-hook and edition-aware editor args.
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
    versions = import ../../../../modules/languages/versions-lib.nix { inherit lib; };
    spec = {
      name = "rustfmt";
      category = "lang.rust.linters";
      install = {
        kind = "project";
      };
      upgrade = "none";
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
    };
  in
  if args.__stdlibMeta or false then
    tool.meta spec
  else
    tool.applyLocal args spec
