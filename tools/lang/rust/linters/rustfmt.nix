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
          pkgs,
          lib,
          ...
        }:
        let
          edition = config.supported.rust.edition or null;
        in
        {
          # Format via devenv treefmt (not a separate git-hooks.rustfmt entry).
          # treefmt-nix defaults programs.rustfmt.edition to "2024". When
          # supported.rust.edition is set, pass it. When unset, invoke via
          # `cargo fmt` so the workspace Cargo.toml edition is honored (bare
          # rustfmt defaults to 2015 and ignores the manifest). Always keep
          # skip_children so out-of-line modules are not double-formatted.
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
                settings.formatter.rustfmt = {
                  # Prefer pkgs.cargo when present (absolute path for treefmt).
                  # Stub pkgs in unit evals often omit cargo — fall back to PATH.
                  command = if pkgs ? cargo then "${pkgs.cargo}/bin/cargo" else "cargo";
                  options = lib.mkForce [
                    "fmt"
                    "--"
                    "--config"
                    "skip_children=true"
                  ];
                };
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
