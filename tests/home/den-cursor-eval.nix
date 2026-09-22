# Pure Den cursor homeConfiguration option checks. Needs flake inputs via
# `nix eval` from the repo root (see den-cursor-cascade.bats). Importing this
# file alone is not enough — use the bats wrapper.
#
# Returns true when both cursor-on and cursor-off fixtures match expectations.
let
  flake = builtins.getFlake (toString ../..);

  on = flake.homeConfigurations.developer;
  off = flake.homeConfigurationsNoCursor.developer;

  must = name: cond: if cond then true else throw "den-cursor-eval: ${name}";

  onCfg = on.config;
  offCfg = off.config;
in
assert must "homeConfigurations.developer exists" (flake.homeConfigurations ? developer);
assert must "cursor-on: cursor.enable" onCfg.cursor.enable;
assert must "cursor-on: llmContext.enable" onCfg.cursor.llmContext.enable;
assert must "cursor-off: no cursor option or disabled" (
  !(offCfg ? cursor) || !offCfg.cursor.enable
);
assert must "cursor-off: no llmContext or disabled" (
  !(offCfg ? cursor)
  || !(offCfg.cursor ? llmContext)
  || !offCfg.cursor.llmContext.enable
);
assert must "cascade metadata lists llm" (
  builtins.elem "cursor-llm" flake.denCursorCascade.cursor.includes
);
assert must "cascade metadata lists extensions" (
  builtins.elem "cursor-extensions" flake.denCursorCascade.cursor.includes
);
true
