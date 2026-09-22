# Thin dual-write shim: devenv modules / project helpers read the Den language
# includes DAG without grepping langOn for "what does python enable?".
# Enable flags still come from Copier → devenv.local.nix (languages.*.enable).
{ lib }:
let
  cascade = import ../../den/language-cascade.nix;
  ideCascade = import ../../den/ide-cascade.nix;
in
rec {
  inherit cascade ideCascade;

  includesOf = name: cascade.${name}.includes or [ ];

  # Expected children for each language hub (W2.2–W2.3 acceptance).
  expectedChildren = {
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

  # Map aspect leaf → which project.nix / module concern it documents.
  leafConcern = {
    hooks = "git-hooks.hooks (modules/hooks/*)";
    ide-recs = "vscode recommendations + cursor language packs (modules/ides)";
    serena = "Serena language_servers (modules/languages/serena.nix)";
    debtmap = "debtmap languages + hook files (modules/debtmap)";
  };

  hubs = cascade.hubs;

  # JS+TS dedupe contract (must stay aligned with project.javascriptOn).
  shared = cascade.shared;

  projectIdeIncludes = ideCascade.project-ides.includes;
}
