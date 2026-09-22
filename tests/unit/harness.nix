# Shared fixtures for topic files. Not a nix-unit suite itself.
{ lib }:
{
  inherit lib;
  versions = import ../../modules/languages/versions-lib.nix { inherit lib; };
  project = import ../../modules/lib/project.nix { inherit lib; };
  denLanguage = import ../../modules/lib/den-language-shim.nix { inherit lib; };
  denProjectBridge = import ../../modules/lib/den-project-bridge.nix { inherit lib; };
  debtmap = import ../../modules/debtmap/lib.nix { inherit lib; };
  term = import ../../home/terminal-lib.nix { inherit lib; };
  terminalCascade = import ../../den/terminal-cascade.nix;
  languageCascade = import ../../den/language-cascade.nix;
  ideCascade = import ../../den/ide-cascade.nix;

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
