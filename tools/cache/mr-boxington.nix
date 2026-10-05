# mr-boxington (mbx): Cargo compile cache — Home Manager / global leaf.
# Repository-local enable is the thin preset's project payload
# (presets/cache/mr-boxington.nix scope = "local"), not a dual mkTool payload:
# applyLocal + mkIf still typechecks `tasks`/`packages` in fixtures that lack
# them. Release pin lives here (install.kind = binary); stdlib/binary.nix builds it.
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
    binary = import ../../stdlib/binary.nix { inherit lib; };

    # Linux: ~/.local/share/mbx/bin; macOS: ~/Library/Application Support/mbx/bin
    # (see https://mr-boxington.jdx.dev/setup).
    shimPathSnippet = ''
      if [ "$(uname -s)" = Darwin ]; then
        _mbx_shim="$HOME/Library/Application Support/mbx/bin"
      else
        _mbx_shim="$HOME/.local/share/mbx/bin"
      fi
      if [ -d "$_mbx_shim" ]; then
        export PATH="$_mbx_shim:$PATH"
      fi
      unset _mbx_shim
    '';

    release = binary.fromGithubRelease {
      pname = "mr-boxington";
      version = "1.22.0";
      owner = "jdx";
      repo = "mr-boxington";
      bin = "mbx";
      archives = {
        x86_64-linux = {
          archive = "mbx-x86_64-unknown-linux-gnu.tar.gz";
          hash = "sha256-6z6MdCd9zIMUInuizTLvAKmjYuyKkM0G72WA60ims3U=";
        };
        aarch64-linux = {
          archive = "mbx-aarch64-unknown-linux-gnu.tar.gz";
          hash = "sha256-t6I1A9nvyzGUHh5ot4+LM2Q6BW8i05z/dF2rbxfttlI=";
        };
        aarch64-darwin = {
          archive = "mbx-aarch64-apple-darwin.tar.gz";
          hash = "sha256-5Ui1dYSYz4IqGAtjKFl+at7Y/puzBGzZGDmRcq4w3eI=";
        };
      };
      # Prebuilt mbx links libgcc_s (not only libc).
      extraBuildInputs = pkgs': [ pkgs'.stdenv.cc.cc.lib ];
      meta = {
        description = "Shared Cargo build cache (mbx) across worktrees";
        license = lib.licenses.mit;
      };
    };

    # Tests may stub pkgs.mr-boxington; real evals use the GitHub release.
    package = pkgs': pkgs'.mr-boxington or (release pkgs');
  in
  tool.binaryLeaf args {
    name = "mr-boxington";
    category = "cache";
    defaultEnable = false;
    inherit package;
    homeManager =
      { pkgs, lib, ... }:
      let
        mbx = package pkgs;
      in
      {
        home = {
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
  }
