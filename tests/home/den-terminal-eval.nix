# Pure Den terminal homeConfiguration option checks (alacritty XOR warp).
# Use via tests/home/den-terminal.bats — needs flake inputs.
let
  flake = builtins.getFlake (toString ../..);

  alacritty = flake.homeConfigurations.developer;
  warp = flake.homeConfigurationsWarp.developer;

  must = name: cond: if cond then true else throw "den-terminal-eval: ${name}";

  onCfg = alacritty.config;
  warpCfg = warp.config;
in
assert must "homeConfigurations.developer exists" (flake.homeConfigurations ? developer);
assert must "homeConfigurationsWarp.developer exists" (flake.homeConfigurationsWarp ? developer);
assert must "alacritty path: terminal.provider" (onCfg.terminal.provider == "alacritty");
assert must "warp path: terminal.provider" (warpCfg.terminal.provider == "warp");
assert must "cascade default includes alacritty-quake" (
  builtins.elem "alacritty-quake" flake.denTerminalCascade.terminal.includes
);
assert must "cascade default excludes warp-quake" (
  !(builtins.elem "warp-quake" flake.denTerminalCascade.terminal.includes)
);
assert must "xor lists both providers" (
  builtins.length flake.denTerminalCascade.terminal.xorProviders == 2
);
assert must "providers mutually exclusive on fixtures" (
  onCfg.terminal.provider != warpCfg.terminal.provider
);
true
