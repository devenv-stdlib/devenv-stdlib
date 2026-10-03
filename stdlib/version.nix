# Release-tracked stdlib version. includes/update/stdlib-version.sh rewrites
# `version` during semantic-release. apiVersion is the major component:
# breaking changes use feat(stdlib)!: so the next release bumps it.
let
  version = "0.1.0";
in
{
  inherit version;
  apiVersion = builtins.head (builtins.split "\\." version);
}
