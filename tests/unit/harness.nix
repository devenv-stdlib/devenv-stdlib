# Shared fixtures for topic files. Not a nix-unit suite itself.
{ lib }:
{
  inherit lib;
  versions = import ../../modules/languages/versions-lib.nix { inherit lib; };
  project = import ../../modules/lib/project.nix { inherit lib; };
  debtmap = import ../../modules/debtmap/lib.nix { inherit lib; };
  term = import ../../home/terminal-lib.nix { inherit lib; };

  policy =
    {
      min,
      max ? null,
      versions ? [ ],
      unsupported ? [ ],
    }:
    {
      inherit
        min
        max
        versions
        unsupported
        ;
    };

  contains = needle: haystack: lib.hasInfix needle haystack;
}
