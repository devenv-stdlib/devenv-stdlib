# Host-side asserts reused by the nixosTest VM. All arguments are store paths.
{
  lib,
  versions,
  project,
  matrixShapes ? import ./matrix-shapes.nix { inherit lib; },
}:
let
  gha = (import ../../stdlib/ci { inherit lib; }).backends.github_actions;
  render = args: gha.render (versions.languageMatrixPlan args);
  emptyYaml = render { };
  pythonYaml = render {
    pythonOn = true;
    python = versions.emptyPython // {
      min = "3.12";
      max = "3.13";
    };
  };
  hooks = project.languageHooks {
    languages = {
      python.enable = true;
      rust.enable = true;
    };
    pythonTypeChecker = "ty";
  };
in
assert
  versions.ubuntuRunners == [
    "ubuntu-24.04"
    "ubuntu-26.04"
  ];
assert versions.problems { } == [ ];
assert lib.hasInfix "workflow_call:" emptyYaml;
assert lib.hasInfix "no-language-matrix:" emptyYaml;
assert lib.hasInfix "ubuntu-24.04" emptyYaml;
assert lib.hasInfix "ubuntu-26.04" emptyYaml;
assert !(lib.hasInfix "ubuntu-22.04" emptyYaml);
assert !(lib.hasInfix "ubuntu-latest" emptyYaml);
assert lib.hasInfix "python:" pythonYaml;
assert lib.hasInfix "3.12" pythonYaml;
assert lib.hasInfix "supported.python.min" pythonYaml;
assert lib.hasInfix "policy_min:" pythonYaml;
assert hooks.ruff;
assert hooks.check-python;
assert hooks.python-debug-statements;
assert hooks.sort-requirements-txt;
assert hooks.ty;
assert !hooks.pyright;
assert hooks.rustfmt;
assert hooks.debtmap;
assert
  project.debtmapLanguages {
    python.enable = true;
    rust.enable = true;
  } == [
    "rust"
    "python"
  ];
assert !(project.languageHooks { }).prettier;
assert !(project.languageHooks { }).debtmap;
assert project.typescriptBundlerMissing true null;
assert matrixShapes.ok;
true
