# Pure Den vs legacy HM parity checks (Phase 3 W3.1).
# Prefer option fingerprints over full home-manager switch.
let
  flake = builtins.getFlake (toString ../..);
  parity = flake.denHmParity;
  must = name: cond: if cond then true else throw "den-hm-parity-eval: ${name}";
in
assert must "overall match" parity.match;
assert must "cursorEnable check" parity.checks.cursorEnable;
assert must "llmEnable check" parity.checks.llmEnable;
assert must "terminalProvider check" parity.checks.terminalProvider;
assert must "programs check" parity.checks.programs;
assert must "packages check" parity.checks.packages;
assert must "systemdUserServices check" parity.checks.systemdUserServices;
assert must "den cursor on" parity.den.cursorEnable;
assert must "legacy cursor on" parity.legacy.cursorEnable;
assert must "den alacritty" (parity.den.terminalProvider == "alacritty");
assert must "legacy alacritty" (parity.legacy.terminalProvider == "alacritty");
true
