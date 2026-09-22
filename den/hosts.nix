# Phase 5 W5.2: den.hosts stubs for NixOS + Darwin class matrix.
# intoAttr = [] → no flake nixosConfigurations / darwinConfigurations yet
# (empty stubs until real hosts; Ubuntu remains den.homes + home-switch).
{ den, ... }:
{
  # Fixture NixOS host (class auto-detected from x86_64-linux).
  den.hosts.x86_64-linux.fixture-nixos = {
    intoAttr = [ ];
    # Avoid touching inputs.darwin / full nixosSystem until product needs builds.
    instantiate = args: {
      inherit args;
      stub = true;
      class = "nixos";
    };
    users.developer = {
      # Host user class only — do not nest HM here (Ubuntu HM = den.homes).
      classes = [ "user" ];
    };
  };

  # Fixture Darwin host (class auto-detected from *-darwin).
  den.hosts.aarch64-darwin.fixture-darwin = {
    intoAttr = [ ];
    instantiate = args: {
      inherit args;
      stub = true;
      class = "darwin";
    };
    users.developer = {
      classes = [ "user" ];
    };
  };

  # Host aspects include the portable shell-tools aspect (cross-class).
  den.aspects.fixture-nixos = {
    includes = [ den.aspects.shell-tools ];
    nixos = {
      denOsHost = {
        name = "fixture-nixos";
        class = "nixos";
      };
    };
  };

  den.aspects.fixture-darwin = {
    includes = [ den.aspects.shell-tools ];
    darwin = {
      denOsHost = {
        name = "fixture-darwin";
        class = "darwin";
      };
    };
  };
}
