# ble.sh line editor. Sourced before Atuin and Starship (mkBefore).
args@{
  pkgs,
  lib,
  config,
  ...
}:
# pkgs and config stay in the signature so Den does not call this without pkgs.
# The false branch is never evaluated; it only marks those names as used.
if false then
  { inherit pkgs config; }
else
  let
    tool = import ../../../stdlib/tool.nix { inherit lib; };
    spec = {
      name = "blesh";
      category = "shell";
      install = {
        kind = "nix";
        attr = "blesh";
      };
      upgrade = "flake";
      defaultEnable = true;
    };
  in
  if args.__stdlibMeta or false then
    tool.meta spec
  else
    tool.apply args (
      spec
      // {
        homeManager =
          {
            pkgs,
            lib,
            config,
            ...
          }:
          lib.mkIf (config.terminal.provider == "alacritty") {
            # ble.sh before Atuin/Starship (those land in initExtra at default order).
            programs.bash.initExtra = lib.mkBefore ''
              source -- "${pkgs.blesh}/share/blesh/ble.sh"
            '';

            home.packages = [ pkgs.blesh ];

            # ble.sh highlighting; ~/.blerc would take precedence if present.
            xdg.configFile."blesh/init.sh".text = ''
              bleopt highlight_syntax=on
            '';
          };
      }
    )
