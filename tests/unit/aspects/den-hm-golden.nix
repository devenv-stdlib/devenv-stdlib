# Phase 4: Den-only HM goldens (no legacy home.nix compare).
# Consumes flake export denHmGolden (see flake.nix).
{ lib, ... }:
let
  flake = builtins.getFlake (toString ../../..);
  golden = flake.denHmGolden;
in
{
  testDenHmGoldenOverallMatch = {
    expr = golden.match;
    expected = true;
  };

  testDenHmGoldenCursorOn = {
    expr = golden.fingerprint.cursorEnable;
    expected = true;
  };

  testDenHmGoldenLlmOn = {
    expr = golden.fingerprint.llmEnable;
    expected = true;
  };

  testDenHmGoldenTerminalAlacritty = {
    expr = golden.fingerprint.terminalProvider;
    expected = "alacritty";
  };

  testDenHmGoldenPrograms = {
    expr = golden.fingerprint.programs;
    expected = golden.expectedPrograms;
  };

  testDenHmGoldenHasMcpSecretsWatch = {
    expr = builtins.elem "mcp-secrets-watch" golden.fingerprint.systemdUserServices;
    expected = true;
  };

  testDenHmGoldenBashOn = {
    expr = golden.fingerprint.programs.bash;
    expected = true;
  };

  testDenHmGoldenBatOn = {
    expr = golden.fingerprint.programs.bat;
    expected = true;
  };

  testDenHmGoldenFdAsPackage = {
    expr = builtins.any (n: lib.hasPrefix "fd" n || n == "fd") golden.fingerprint.packages;
    expected = true;
  };

  testDenHmGoldenRipgrepAsPackage = {
    expr = builtins.any (n: lib.hasPrefix "ripgrep" n || n == "ripgrep") golden.fingerprint.packages;
    expected = true;
  };
}
