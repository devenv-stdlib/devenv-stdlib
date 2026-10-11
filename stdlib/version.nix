# Release-tracked stdlib version. includes/update/stdlib-version.sh rewrites
# `version` during semantic-release. apiVersion is the major component:
# breaking changes need a BREAKING CHANGE: footer so the angular preset
# bumps the major and apiVersion follows.
let
  version = "1.0.0";
in
{
  inherit version;
  apiVersion = builtins.head (builtins.split "\\." version);
}
