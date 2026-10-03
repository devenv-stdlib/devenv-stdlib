# B3 re-homed: HM-only terminal aspects stay off nixos and darwin hosts.
{ lib, ... }:
let
  inherit (import ../stdlib/preset.nix { inherit lib; }) mkPreset hostClass;

  hmOnly = [
    "terminal"
    "alacritty-quake"
    "warp-quake"
  ];

  onOs = class: class == "nixos" || class == "darwin";
in
{
  imports = [
    (mkPreset {
      name = "host-hm-only-guard";
      description = "Exclude HM-only terminal aspects from nixos and darwin hosts.";

      extraOptions = {
        hostClass = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "OS class for the requires check. null is Home Manager, not an OS host.";
        };
        selected = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Aspect names selected on this host. OS hosts must not keep HM-only ones.";
        };
      };

      # Policy exclude is the rule. requires fails only when an OS host still
      # has one of these aspects selected and this preset would not drop it.
      exclude = ctx: lib.optionals (onOs (hostClass ctx)) hmOnly;

      requires = [
        {
          assertion =
            cfg:
            let
              class = cfg.presets.host-hm-only-guard.hostClass or null;
              selected = cfg.presets.host-hm-only-guard.selected or [ ];
              dropped = lib.optionals (onOs class) hmOnly;
              remaining = lib.filter (name: builtins.elem name selected && !(builtins.elem name dropped)) hmOnly;
            in
            remaining == [ ];
          message = "HM-only terminal aspects cannot be enabled on nixos or darwin hosts";
        }
      ];
    })
  ];
}
