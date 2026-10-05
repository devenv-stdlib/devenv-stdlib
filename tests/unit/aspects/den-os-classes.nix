# Phase 5: portable aspect × two OS classes + Ubuntu-only quake guards.
# Consumes flake export denOsClasses (see flake.nix).
_:
let
  flake = builtins.getFlake (toString ../../..);
  os = flake.denOsClasses;
in
{
  testDenOsClassesOverallMatch = {
    expr = os.match;
    expected = true;
  };

  testDenOsHostsNixosClass = {
    expr = os.hosts.nixos.class;
    expected = "nixos";
  };

  testDenOsHostsDarwinClass = {
    expr = os.hosts.darwin.class;
    expected = "darwin";
  };

  testDenOsHostsAreStubs = {
    expr = {
      nixos = os.hosts.nixos.intoAttr;
      darwin = os.hosts.darwin.intoAttr;
    };
    expected = {
      nixos = [ ];
      darwin = [ ];
    };
  };

  testDenOsShellToolsNixosNonEmpty = {
    expr = os.shellTools.nixos.aspect or null;
    expected = "shell-tools";
  };

  testDenOsShellToolsDarwinNonEmpty = {
    expr = os.shellTools.darwin.aspect or null;
    expected = "shell-tools";
  };

  testDenOsShellToolsSamePayloadBothClasses = {
    expr = os.shellTools.nixos.tools == os.shellTools.darwin.tools;
    expected = true;
  };

  testDenOsShellToolsExpectedList = {
    expr = os.shellTools.nixos.tools;
    expected = os.shellTools.expectedTools;
  };

  testDenOsHostAspectsIncludeShellTools = {
    expr = {
      nixos = os.hostAspects.nixosIncludesShellTools;
      darwin = os.hostAspects.darwinIncludesShellTools;
    };
    expected = {
      nixos = true;
      darwin = true;
    };
  };

  # Ubuntu-only: GNOME quake / Warp keybinding must not ship OS class config.
  testDenOsAlacrittyQuakeHasNoOsClasses = {
    expr = {
      nixos = os.ubuntuOnlyGuards.alacritty-quake.hasNixos;
      darwin = os.ubuntuOnlyGuards.alacritty-quake.hasDarwin;
      hm = os.ubuntuOnlyGuards.alacritty-quake.hasHomeManager;
    };
    expected = {
      nixos = false;
      darwin = false;
      hm = true;
    };
  };

  testDenOsWarpQuakeHasNoOsClasses = {
    expr = {
      nixos = os.ubuntuOnlyGuards.warp-quake.hasNixos;
      darwin = os.ubuntuOnlyGuards.warp-quake.hasDarwin;
      hm = os.ubuntuOnlyGuards.warp-quake.hasHomeManager;
    };
    expected = {
      nixos = false;
      darwin = false;
      hm = true;
    };
  };

  testDenOsTerminalHubHasNoOsClasses = {
    expr = {
      nixos = os.ubuntuOnlyGuards.terminal.hasNixos;
      darwin = os.ubuntuOnlyGuards.terminal.hasDarwin;
    };
    expected = {
      nixos = false;
      darwin = false;
    };
  };
}
