# Phase 3 W3.3: custom project class (devenv bridge target).
# Content under den.aspects.<name>.project is resolved via den.lib.aspects.resolve
# and imported into devenv-shaped evalModules — no devenv fork, no flake-parts shells.
_: {
  den.classes.project = {
    description = "devenv project shell / toolchain options (resolve → modules/ imports)";
  };
}
