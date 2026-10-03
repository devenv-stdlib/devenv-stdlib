# Zellij multiplexer. Session names and theme stay on options.alacritty.*.
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
      name = "zellij";
      category = "terminal.mux";
      install = {
        kind = "hm-program";
        program = "zellij";
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
          { lib, config, ... }:
          lib.mkIf (config.terminal.provider == "alacritty") {
            programs.zellij = {
              enable = true;
              # Shell integration stays off: it would start Zellij in every shell,
              # including the devenv one. The Alacritty desktop entry starts it instead.
              settings = {
                default_layout = "compact";
                copy_command = "wl-copy";
                show_startup_tips = false;
                theme = config.alacritty.zellijTheme;
              };
            };
          };
      }
    )
