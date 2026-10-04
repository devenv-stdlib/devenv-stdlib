# mr-boxington (mbx): Cargo compile cache — Home Manager / global leaf.
# Repository-local enable is the thin preset's project payload
# (presets/cache/mr-boxington.nix scope = "local"), not a dual mkTool payload:
# applyLocal + mkIf still typechecks `tasks`/`packages` in fixtures that lack
# them. Binary package: stdlib/mr-boxington.nix (GitHub releases).
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
    tool = import ../../stdlib/tool.nix { inherit lib; };

    # Linux: ~/.local/share/mbx/bin; macOS: ~/Library/Application Support/mbx/bin
    # (see https://mr-boxington.jdx.dev/setup).
    shimDirLinux = "$HOME/.local/share/mbx/bin";
    shimDirDarwin = "$HOME/Library/Application Support/mbx/bin";
    shimPathSnippet = ''
      if [ "$(uname -s)" = Darwin ]; then
        _mbx_shim="${shimDirDarwin}"
      else
        _mbx_shim="${shimDirLinux}"
      fi
      if [ -d "$_mbx_shim" ]; then
        export PATH="$_mbx_shim:$PATH"
      fi
      unset _mbx_shim
    '';

    # Tests may stub pkgs.mr-boxington; real evals build from stdlib/.
    mbxFor = pkgs: pkgs.mr-boxington or (import ../../stdlib/mr-boxington.nix { inherit pkgs; });

    spec = {
      name = "mr-boxington";
      category = "cache";
      install = {
        # In-repo binary package (stdlib/mr-boxington.nix), not a nixpkgs attr.
        kind = "binary";
      };
      # Pin bumps are manual in stdlib/mr-boxington.nix.
      upgrade = "self";
      defaultEnable = false;
      homeManager =
        { pkgs, lib, ... }:
        let
          mbx = mbxFor pkgs;
        in
        {
          home = {
            packages = [ mbx ];
            file.".bashrc.d/25-mr-boxington.sh".text = ''
              # Cargo shim from `mbx setup --global` (see tools.mr-boxington).
              ${shimPathSnippet}
            '';
            activation.mrBoxingtonSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              # Use the store package (not PATH): activation PATH may lack mbx.
              # Scope flag selects the mise config; do not pass --yes (rejected).
              # Best-effort: warn on stderr, do not fail home-switch.
              if ! ${lib.getExe mbx} setup --global; then
                echo "mr-boxington: mbx setup --global failed (continuing)" >&2
              fi
            '';
          };
        };
    };
  in
  if args.__stdlibMeta or false then tool.meta spec else tool.apply args spec
