{
  pkgs,
  lib,
  ...
}:
let
  nonNix = import ../modules/non-nix/lib.nix { inherit lib; };
  resolved = nonNix.resolve pkgs;
  user = nonNix.filterScope "user" resolved;
  userNix = nonNix.nixPackages user;
  miseToml = nonNix.toMiseToml user;
  userImages = nonNix.dockerImages user;
  # Catalog may also promote pkgs.uv into userNix; duplicate on packages is fine.
in
{
  home = {
    packages = [
      pkgs.mise
      pkgs.uv
    ]
    ++ userNix;

    file = {
      ".config/mise/conf.d/devenv4monorepo.toml".text = miseToml;
      ".bashrc.d/20-mise.sh".text = ''
        if command -v mise >/dev/null 2>&1; then
          eval "$(mise activate bash)"
        fi
      '';
    };

    activation.miseInstallNonNix = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      export PATH=${
        lib.escapeShellArg (
          lib.makeBinPath [
            pkgs.mise
            pkgs.uv
            pkgs.curl
            pkgs.coreutils
          ]
        )
      }:$PATH
      # Prefer the profile/store uv so pipx: tools never fall back to missing pipx.
      export MISE_PIPX_UVX=1
      ${lib.getExe pkgs.mise} install || true
      ${lib.concatMapStrings (img: ''
        if command -v docker >/dev/null 2>&1; then
          docker pull ${lib.escapeShellArg img} || true
        fi
      '') userImages}
    '';
  };
}
