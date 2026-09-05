# Host-side asserts reused by the nixosTest VM. All arguments are store paths.
{
  lib,
  versions,
  project,
}:
let
  emptyYaml = versions.workflowText { };
  pythonYaml = versions.workflowText {
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
assert versions.runner == "ubuntu-22.04";
assert versions.problems { } == [ ];
assert lib.hasInfix "workflow_call:" emptyYaml;
assert lib.hasInfix "no-language-matrix:" emptyYaml;
assert !(lib.hasInfix "ubuntu-latest" emptyYaml);
assert lib.hasInfix "python:" pythonYaml;
assert lib.hasInfix "3.12" pythonYaml;
assert hooks.ruff;
assert hooks.ty;
assert !hooks.pyright;
assert hooks.rustfmt;
assert !(project.languageHooks { }).prettier;
assert project.typescriptBundlerMissing true null;
true
