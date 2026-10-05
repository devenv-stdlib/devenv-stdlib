# Local rustfmt via treefmt, edition-aware editor args.
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
    spec = {
      name = "rustfmt";
      category = "lang.rust.linters";
      install = {
        kind = "project";
      };
      upgrade = "none";
      project =
        {
          config,
          lib,
          ...
        }:
        let
          edition = config.supported.rust.edition or null;
        in
        {
          # Format via devenv treefmt (not a separate git-hooks.rustfmt entry).
          # treefmt passes matched paths to the formatter; use rustfmt directly
          # (cargo fmt is crate-oriented and unsupported for treefmt file lists).
          # treefmt-nix defaults programs.rustfmt.edition to "2024". When
          # supported.rust.edition is set, pass it. When unset, omit --edition
          # so rustfmt.toml can supply it (bare rustfmt otherwise defaults to
          # 2015). Always keep skip_children so out-of-line modules are not
          # double-formatted. Prefer setting supported.rust.edition (
          # does) for an explicit workspace edition.
          treefmt.config =
            if edition != null then
              {
                programs.rustfmt = {
                  enable = true;
                  inherit edition;
                };
              }
            else
              {
                programs.rustfmt.enable = true;
                settings.formatter.rustfmt.options = lib.mkForce [
                  "--config"
                  "skip_children=true"
                ];
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
  if args.__stdlibMeta or false then tool.meta spec else tool.applyLocal args spec
