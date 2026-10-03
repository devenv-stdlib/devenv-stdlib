# Shared supported.* option fields. Not a preset (underscore: loader skips it).
{ lib }:
extra:
{
  min = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "Minimum supported version (required when the language is enabled).";
  };
  max = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "Optional maximum supported version.";
  };
  unsupported = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Versions between min and max that must not be used (for example a Rust ICE).";
  };
  versions = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = ''
      Versions to test in CI. When min/max omit a patch (3.12, 22), defaults
      to each catalog cycle's latest patch between min and max, minus EOL
      and unsupported. When a patch is set (1.80.0), defaults to stepping
      the one component that changes, minus unsupported.
    '';
  };
}
// extra
