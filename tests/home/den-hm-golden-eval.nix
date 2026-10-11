# Pure Den-only HM golden checks (Phase 4).
# Prefer option fingerprints over full home-manager switch.
let
  flake = builtins.getFlake (toString ../..);
  golden = flake.denHmGolden;
  must = name: cond: if cond then true else throw "den-hm-golden-eval: ${name}";
in
assert must "overall match" golden.match;
assert must "cursor on" golden.fingerprint.cursorEnable;
assert must "llm on" golden.fingerprint.llmEnable;
assert must "alacritty" (golden.fingerprint.terminalProvider == "alacritty");
assert must "programs" (golden.fingerprint.programs == golden.expectedPrograms);
assert must "mcp-secrets-watch" (
  builtins.elem "mcp-secrets-watch" golden.fingerprint.systemdUserServices
);
true
