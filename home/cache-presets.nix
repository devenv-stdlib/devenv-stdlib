# Home Manager bridge for opt-in cache presets (home.local.nix → home-switch).
#
# mkPreset / den.aspects."cache.*" are decided in the outer Den eval
# (packaging/den-outputs.nix). home.local.nix is imported later inside HM
# (modules/den/homes.nix), so presets.cache.* there cannot flip those aspects.
# This module declares the same options on the HM tree and, when
# enable && scope == "global", turns on the tool leaf (binaryLeaf / setup).
{ lib, config, ... }:
let
  scopeType = lib.types.enum [
    "local"
    "global"
  ];

  mkCachePreset = name: {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the cache.${name} preset for this user profile (home-switch).";
    };
    scope = lib.mkOption {
      type = scopeType;
      default = "local";
      description = ''
        Where to enable cache.${name}.

        - `local` — no-op here; use devenv.local.nix for repository-local install.
        - `global` — enable tools.${name} on this Home Manager profile.
      '';
    };
  };

  cfg = name: config.presets.cache.${name};
  globalOn = name: (cfg name).enable && (cfg name).scope == "global";
in
{
  options.presets.cache = {
    mr-boxington = mkCachePreset "mr-boxington";
    build-cleaner = mkCachePreset "build-cleaner";
  };

  config = {
    tools.mr-boxington.enable = lib.mkIf (globalOn "mr-boxington") true;
    tools.build-cleaner.enable = lib.mkIf (globalOn "build-cleaner") true;
  };
}
