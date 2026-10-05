# CircleCI MatrixPlan backend — phase-1 stub.
# Full sync to .circleci/config.yml is deferred (design M4).
{ lib }:
rec {
  # Stable API: render :: MatrixPlan → { implemented, path, text, message }
  # Callers must check `implemented` before writing files.
  render = _plan: {
    implemented = false;
    path = ".circleci/config.yml";
    text = null;
    message = ''
      stdlib.ci.backends.circleci.render is a phase-1 stub.
      MatrixPlan IR and the GitHub Actions backend are implemented;
      ship ci.circleci.language-matrix (design M4; github.com/thedrow/devenv4monorepo/issues/127).
    '';
  };

  # Convenience for presets that want eval to fail closed when enabled early.
  renderOrThrow =
    plan:
    let
      r = render plan;
    in
    if r.implemented then r.text else throw (lib.removeSuffix "\n" r.message);
}
