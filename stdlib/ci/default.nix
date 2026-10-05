# stdlib.ci — provider-agnostic matrix IR + provider backends.
{ lib }:
{
  matrix = import ./matrix.nix { inherit lib; };
  backends = {
    github_actions = import ./backends/github_actions.nix { inherit lib; };
    circleci = import ./backends/circleci.nix { inherit lib; };
  };
}
