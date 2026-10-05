# Derive microsoft/PR-Metrics `code-file-extensions` from enabled languages.
# Always includes Nix + GHA YAML; docs site tooling (or JS/TS) adds html/ts/tsx.
# Providing this input replaces the Action's top-10 default set.
{ lib }:
let
  supported = import ../../../../stdlib/devenv-supported.nix;

  # Primary product extensions per devenv `languages.*` id (not full linguist).
  languageExtensions = {
    ansible = [
      "yml"
      "yaml"
    ];
    c = [
      "c"
      "h"
    ];
    clojure = [
      "clj"
      "cljs"
      "cljc"
      "edn"
    ];
    cplusplus = [
      "cpp"
      "cc"
      "cxx"
      "hpp"
      "hh"
      "hxx"
    ];
    crystal = [ "cr" ];
    cue = [ "cue" ];
    dart = [ "dart" ];
    deno = [
      "ts"
      "tsx"
      "js"
      "jsx"
    ];
    dotnet = [
      "cs"
      "fs"
      "vb"
    ];
    elixir = [
      "ex"
      "exs"
    ];
    elm = [ "elm" ];
    erlang = [
      "erl"
      "hrl"
    ];
    fortran = [
      "f"
      "f90"
      "f95"
      "for"
    ];
    gawk = [
      "awk"
      "gawk"
    ];
    gleam = [ "gleam" ];
    go = [ "go" ];
    hare = [ "ha" ];
    haskell = [
      "hs"
      "lhs"
    ];
    helm = [
      "yml"
      "yaml"
      "tpl"
    ];
    idris = [
      "idr"
      "lidr"
    ];
    java = [ "java" ];
    javascript = [
      "js"
      "jsx"
      "mjs"
      "cjs"
    ];
    jsonnet = [
      "jsonnet"
      "libsonnet"
    ];
    julia = [ "jl" ];
    kotlin = [
      "kt"
      "kts"
    ];
    lean4 = [
      "lean"
      "lean4"
    ];
    lobster = [ "lobster" ];
    lua = [ "lua" ];
    nim = [
      "nim"
      "nims"
    ];
    nix = [ "nix" ];
    ocaml = [
      "ml"
      "mli"
    ];
    odin = [ "odin" ];
    opentofu = [
      "tf"
      "tfvars"
    ];
    pascal = [
      "pas"
      "pp"
    ];
    perl = [
      "pl"
      "pm"
      "t"
    ];
    php = [ "php" ];
    pkl = [ "pkl" ];
    purescript = [ "purs" ];
    python = [
      "py"
      "pyi"
    ];
    r = [
      "r"
      "R"
      "rmd"
      "Rmd"
    ];
    racket = [
      "rkt"
      "rktd"
      "rktl"
    ];
    raku = [
      "raku"
      "rakumod"
      "rakutest"
      "p6"
    ];
    robotframework = [
      "robot"
      "resource"
    ];
    ruby = [
      "rb"
      "rake"
      "gemspec"
    ];
    rust = [ "rs" ];
    scala = [
      "scala"
      "sc"
    ];
    shell = [
      "sh"
      "bash"
      "bats"
    ];
    solidity = [ "sol" ];
    standardml = [
      "sml"
      "ml"
    ];
    swift = [ "swift" ];
    terraform = [
      "tf"
      "tfvars"
    ];
    texlive = [
      "tex"
      "sty"
      "cls"
    ];
    typescript = [
      "ts"
      "tsx"
    ];
    typst = [ "typ" ];
    unison = [ "u" ];
    v = [ "v" ];
    vala = [
      "vala"
      "vapi"
    ];
    zig = [
      "zig"
      "zon"
    ];
  };

  # Always-on for this Nix + GitHub Actions monorepo template (sorted).
  alwaysBase = [
    "nix"
    "yaml"
    "yml"
  ];

  # Docs site (Vite/React) without requiring languages.typescript.enable —
  # this template keeps languages off for docs/ (see docs/content/contributing.md).
  docsExtensions = [
    "html"
    "ts"
    "tsx"
  ];

  langOn = languages: name: (languages.${name} or { }).enable or false;

  # Newline-separated extension list for the Action `code-file-extensions` input.
  codeFileExtensions =
    {
      languages ? { },
      docsTooling ? false,
      languageIds ? supported.languages,
    }:
    let
      on = langOn languages;
      fromLangs = lib.concatMap (
        name: lib.optionals (on name) (languageExtensions.${name} or [ ])
      ) languageIds;
      jsTsOn = on "javascript" || on "typescript" || on "deno";
      docs = lib.optionals (docsTooling || jsTsOn) docsExtensions;
      all = lib.unique (alwaysBase ++ fromLangs ++ docs);
      sorted = builtins.sort (a: b: a < b) all;
    in
    lib.concatStringsSep "\n" sorted;
in
{
  inherit
    languageExtensions
    alwaysBase
    docsExtensions
    langOn
    codeFileExtensions
    ;
}
