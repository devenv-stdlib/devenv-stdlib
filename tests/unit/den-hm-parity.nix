# Phase 3 W3.1: Den homeConfiguration fingerprint ≡ legacy home.nix (fixture).
# Consumes flake exports denHmParity (see flake.nix).
{ lib, ... }:
let
  flake = builtins.getFlake (toString ../..);
  parity = flake.denHmParity;
in
{
  testDenHmParityOverallMatch = {
    expr = parity.match;
    expected = true;
  };

  testDenHmParityCursorEnable = {
    expr = parity.checks.cursorEnable;
    expected = true;
  };

  testDenHmParityLlmEnable = {
    expr = parity.checks.llmEnable;
    expected = true;
  };

  testDenHmParityTerminalProvider = {
    expr = parity.checks.terminalProvider;
    expected = true;
  };

  testDenHmParityPrograms = {
    expr = parity.checks.programs;
    expected = true;
  };

  testDenHmParityPackages = {
    expr = parity.checks.packages;
    expected = true;
  };

  testDenHmParitySystemdUserServices = {
    expr = parity.checks.systemdUserServices;
    expected = true;
  };

  # Sanity: fixture is cursor-on + alacritty on both sides.
  testDenHmParityDenCursorOn = {
    expr = parity.den.cursorEnable;
    expected = true;
  };

  testDenHmParityLegacyCursorOn = {
    expr = parity.legacy.cursorEnable;
    expected = true;
  };

  testDenHmParityDenTerminalAlacritty = {
    expr = parity.den.terminalProvider;
    expected = "alacritty";
  };

  testDenHmParityLegacyTerminalAlacritty = {
    expr = parity.legacy.terminalProvider;
    expected = "alacritty";
  };
}
