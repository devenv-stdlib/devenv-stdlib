{
  lib,
  config,
  ...
}:
let
  versions = import ../languages/versions-lib.nix { inherit lib; };
  on = (config.languages.rust or { }).enable or false;
in
{
  git-hooks.hooks = {
    rustfmt = {
      enable = on;
      args = versions.rustfmtEditionArgs (config.supported.rust.edition or null);
    };
    clippy.enable = on;
  };
}
