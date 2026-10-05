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
          # Format via devenv treefmt (not a separate git-hooks.rustfmt entry).
          # treefmt-nix defaults programs.rustfmt.edition to "2024"; when the
          # workspace has no supported.rust.edition, clear --edition so rustfmt
          # follows Cargo.toml / rustfmt.toml (2021 workspaces stay valid).
          # Nest edition under programs.rustfmt — a sibling `//` would replace
          # `{ enable = true; }` entirely (same pitfall as yamlfmt settings).
          treefmt.config = {
            programs.rustfmt = {
              enable = true;
            }
            // lib.optionalAttrs (edition != null) { inherit edition; };
          }
          // lib.optionalAttrs (edition == null) {
            settings.formatter.rustfmt.options = lib.mkForce [ ];
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
