{
  lib,
  inputs ? { },
  ...
}:
let
  # Import the devenv loader; stdlib/default.nix is the public stdlib entrypoint.
  devenvLoad = import ../stdlib/devenv.nix {
    inherit lib;
    nix-log = inputs.nix-log or null;
  };
in
{
  imports = [
    ./packages
    # First-class linters.* (treefmt + residual prek). Parallel to languages.*.
    ./linters
    ./hooks/common.nix
    # Local mkTool leaves under tools/lang/... plus thin presets under
    # presets/<lang>/<category>/ (attrpaths like python.lint.ruff). Applied
    # below via stdlib.devenv.load. No empty compat shims for the old
    # modules/hooks or modules/ides paths — pre-release, nothing public to
    # break. presets/examples/ is documentation only.
    # CI language/OS matrix strategy is
    # presets/ci/github_actions/language-matrix.nix
    # (attrpath ci.github_actions.language-matrix).
    # Opt-in PR quality / AI-slop gate is
    # presets/ci/github_actions/anti-slop.nix
    # (attrpath ci.github_actions.anti-slop → pr-quality.yml; dogfood enable in
    # root devenv.nix). presets/examples/ is documentation only.
    # Evidence-grounded PR review diffs are
    # presets/ci/github_actions/aletheore.nix
    # (attrpath ci.github_actions.aletheore → aletheore.yml).
    ./debtmap/hooks.nix
    ./languages
    ./debtmap
    ./mise
    ./non-nix
    ./update
    ./test/devenv.nix
  ]
  ++ devenvLoad.load {
    presets = devenvLoad.defaultRoots ../presets;
    tools = [ ../tools ];
  };
}
