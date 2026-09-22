# Phase 2 W2.1: Den terminal aspect includes DAG + provider XOR.
{ lib, terminalCascade, ... }:
let
  cascade = terminalCascade;
  includesOf = name: cascade.${name}.includes or [ ];
  hasInclude = aspect: child: builtins.elem child (includesOf aspect);
in
{
  testDenTerminalDefaultIncludesAlacritty = {
    expr = hasInclude "terminal" "alacritty-quake";
    expected = true;
  };

  testDenTerminalDefaultDoesNotIncludeWarp = {
    expr = hasInclude "terminal" "warp-quake";
    expected = false;
  };

  testDenTerminalXorProviders = {
    expr = lib.sort (a: b: a < b) cascade.terminal.xorProviders;
    expected = [
      "alacritty-quake"
      "warp-quake"
    ];
  };

  testDenTerminalXorExactlyTwo = {
    expr = builtins.length cascade.terminal.xorProviders;
    expected = 2;
  };

  testDenTerminalProviderAspectMap = {
    expr = cascade.providerAspect;
    expected = {
      alacritty = "alacritty-quake";
      warp = "warp-quake";
    };
  };

  testDenTerminalLeavesHaveNoNestedIncludes = {
    expr = {
      alacritty = includesOf "alacritty-quake";
      warp = includesOf "warp-quake";
    };
    expected = {
      alacritty = [ ];
      warp = [ ];
    };
  };

  # XOR guard: hub must never list both providers at once.
  testDenTerminalHubNeverIncludesBothProviders = {
    expr =
      let
        kids = includesOf "terminal";
        both = builtins.elem "alacritty-quake" kids && builtins.elem "warp-quake" kids;
      in
      both;
    expected = false;
  };

  testDenTerminalAlacrittyPathReachable = {
    expr =
      let
        developerIncludes = [ "terminal" ];
        reachable = lib.unique (lib.concatMap (name: [ name ] ++ (includesOf name)) developerIncludes);
      in
      lib.sort (a: b: a < b) reachable;
    expected = [
      "alacritty-quake"
      "terminal"
    ];
  };

  testDenTerminalWarpPathReachable = {
    expr =
      let
        # Alternate hub includes (Warp fixture).
        terminalIncludes = [ "warp-quake" ];
        reachable = lib.unique (
          [ "terminal" ] ++ terminalIncludes ++ lib.concatMap includesOf terminalIncludes
        );
      in
      lib.sort (a: b: a < b) reachable;
    expected = [
      "terminal"
      "warp-quake"
    ];
  };
}
