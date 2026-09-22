# Phase 5 W5.1: portable shell CLIs / integrations across OS classes.
# One shared payload lands on nixos + darwin (no copy-paste). Ubuntu HM packages
# stay in home-cli; this aspect documents the portable tool list for host stubs.
{ den, ... }:
let
  # Single definition → both OS classes (Phase 5 acceptance).
  portable = {
    denOsPortable = {
      aspect = "shell-tools";
      tools = [
        "ripgrep"
        "fd"
        "bat"
        "fzf"
        "direnv"
        "zoxide"
      ];
      shellIntegrations = [
        "bash"
        "starship"
        "direnv"
        "zoxide"
        "fzf"
      ];
    };
  };
in
{
  den.aspects.shell-tools = {
    includes = [ ];

    # Same attrset reference for both classes — no duplicated module bodies.
    nixos = portable;
    darwin = portable;
  };
}
