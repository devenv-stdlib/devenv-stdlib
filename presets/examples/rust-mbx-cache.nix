# Example composition only — not loaded by modules/devenv.nix defaultRoots.
# Opt-in: load presets/examples (or copy the workflows into a consumer preset).
#
# Intent: with cache.mr-boxington local + a rust:build task (#73), run
#   doctor before build; gc + stats after.
# Entry: `devenv tasks run rust:build --mode all` (default `before` mode skips
# downstream gc/stats; `--mode all` includes the after edges).
args@{ lib, ... }:
let
  toolLib = import ../../stdlib/tool.nix { inherit lib; };
  loadLib = import ../../stdlib/load.nix { inherit lib; };
  toolRefs = toolLib.refsFromSpecs (toolLib.specs (loadLib.discover [ ../../tools ]));

  thin = {
    path = [
      "examples"
      "rust-mbx-cache"
    ];
    description = ''
      Example workflow: mr-boxington doctor before rust:build; gc and stats after.
      Enable presets.cache.mr-boxington (local) and provide rust:build (see #73).
      Run with: devenv tasks run rust:build --mode all
    '';
    defaultEnable = false;
    categoryPolicy = false;
    when = _: true;
    # tool-ref embeds tasks via refsFromSpecs — works even if load omits tool roots.
    exportTasks = [ toolRefs.cache.mr-boxington ];
    workflows = [
      {
        around = "rust:build";
        before = [ "mr-boxington:doctor" ];
        after = [
          "mr-boxington:gc"
          "mr-boxington:stats"
        ];
      }
    ];
    tools = [ ];
    project = { };
  };
in
if args ? tools then
  thin
else
  {
    # Den / HM: documentation-only; no homeManager payload.
  }
