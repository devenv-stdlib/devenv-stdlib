# mr-boxington (mbx): Cargo compile cache. Dual scope — Home Manager (global)
# and devenv/project (local). Upstream setup flags match: mbx setup --global /
# --local. Binary package lives in stdlib/mr-boxington.nix (GitHub releases).
#
# One module body for both loaders (do not branch apply/applyLocal on
# config/options — that recurses). Gate payloads with mkIf on `options ? home`.
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
    # Optional: meta probe omits it; module eval always provides it.
    options = args.options or { };
    tool = import ../../stdlib/tool.nix { inherit lib; };

    # Shim dir that `mbx setup` installs (Linux default). Prepend so plain
    # cargo resolves to the mbx wrapper after setup.
    shimDir = "$HOME/.local/share/mbx/bin";

    # Tests may stub pkgs.mr-boxington; real evals build from stdlib/.
    mbxFor = pkgs: pkgs.mr-boxington or (import ../../stdlib/mr-boxington.nix { inherit pkgs; });

    homeManager =
      { pkgs, lib, ... }:
      {
        home = {
          packages = [ (mbxFor pkgs) ];
          file.".bashrc.d/25-mr-boxington.sh".text = ''
            # Cargo shim from `mbx setup --global` (see tools.mr-boxington).
            if [ -d "${shimDir}" ]; then
              export PATH="${shimDir}:$PATH"
            fi
          '';
          activation.mrBoxingtonSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            # Scope flag selects the mise config; do not pass --yes (rejected).
            if command -v mbx >/dev/null 2>&1; then
              mbx setup --global || true
            fi
          '';
        };
      };

    project =
      { pkgs, ... }:
      {
        packages = [ (mbxFor pkgs) ];
        # After generated mise.toml; --local installs the Cargo shim / mise
        # wrapper. Regenerated mise.toml does not remove the shim.
        tasks."mr-boxington:setup" = {
          exec = ''
            set -euo pipefail
            mbx setup --local || true
          '';
          after = [ "mise:install" ];
        };
        tasks."devenv:enterShell".after = [ "mr-boxington:setup" ];
        enterShell = ''
          if [ -d "${shimDir}" ]; then
            export PATH="${shimDir}:$PATH"
          fi
        '';
      };

    fullSpec = {
      name = "mr-boxington";
      category = "cache";
      install = {
        # In-repo binary package (stdlib/mr-boxington.nix), not a nixpkgs attr.
        kind = "binary";
      };
      # Pin bumps are manual in stdlib/mr-boxington.nix.
      upgrade = "self";
      defaultEnable = false;
      inherit homeManager project;
    };
  in
  if args.__stdlibMeta or false then
    tool.meta fullSpec
  else
    let
      checked = tool.meta fullSpec;
      cfgEnable = config.tools.${checked.name}.enable;
    in
    {
      options.tools.${checked.name}.enable = lib.mkOption {
        type = lib.types.bool;
        default = checked.defaultEnable;
        description = "Enable the ${checked.name} tool (${checked.category}; ${lib.concatStringsSep "+" checked.scopes}).";
      };
      # optionalAttrs (not mkIf) so the inactive payload's option paths are
      # absent — mkIf false still typechecks `home.*` / `packages` and fails
      # in the other evaluator. `options ? home` discriminates Den/HM vs devenv.
      config = lib.mkIf cfgEnable ((if options ? home then homeManager else project) args);
    }
