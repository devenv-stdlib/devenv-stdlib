# Shared fixtures for topic files. Not a nix-unit suite itself.
{ lib }:
{
  inherit lib;
  versions = import ../../modules/languages/versions-lib.nix { inherit lib; };
  stdlib = import ../../stdlib { inherit lib; };
  ci = (import ../../stdlib { inherit lib; }).ci;
  project = import ../../modules/lib/project.nix { inherit lib; };
  debtmap = import ../../modules/debtmap/lib.nix { inherit lib; };
  term = import ../../home/terminal-lib.nix { inherit lib; };
  terminalCascade = import ../../modules/den/_cascades/terminal-cascade.nix;
  languageCascade = import ../../modules/den/_cascades/language-cascade.nix;
  ideCascade = import ../../modules/den/_cascades/ide-cascade.nix;

  # Expected language hub → leaf names (cascade goldens; was den-language-shim).
  expectedLanguageChildren = {
    python = [
      "python-hooks"
      "python-ide-recs"
      "python-serena"
      "python-debtmap"
    ];
    rust = [
      "rust-hooks"
      "rust-ide-recs"
      "rust-serena"
      "rust-debtmap"
    ];
    go = [
      "go-hooks"
      "go-ide-recs"
      "go-serena"
      "go-debtmap"
    ];
    javascript = [
      "javascript-hooks"
      "javascript-ide-recs"
      "javascript-serena"
      "javascript-debtmap"
    ];
    typescript = [
      "typescript-hooks"
      "typescript-ide-recs"
      "typescript-serena"
      "typescript-debtmap"
    ];
  };

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
