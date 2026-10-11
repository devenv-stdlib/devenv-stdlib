# stdlib.ci — provider-agnostic matrix / attachment IR + provider backends.
# Phase 1 ships GitHub Actions only; other providers are tracked in issues.
{ lib }:
{
  matrix = import ./matrix.nix { inherit lib; };
  attachments = import ./attachments.nix { inherit lib; };
  backends = {
    github_actions = import ./backends/github_actions.nix { inherit lib; };
  };
}
