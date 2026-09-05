{
  pkgs,
  lib,
  config,
  ...
}:
let
  project = import ./project-lib.nix { inherit lib; };
  typescriptOn = (config.languages.typescript or { }).enable or false;
  bundlers = project.typescriptBundlers;
in
{
  options = {
    python.extensionToolchain = lib.mkEnableOption ''
      C, C++, and Rust compilers so pip/uv can build Python extensions from
      source when wheels or Homebrew bottles are missing. Does not enable
      languages.c, languages.cplusplus, or languages.rust
    '';

    pythonTypeChecker = lib.mkOption {
      type = lib.types.enum [
        "pyright"
        "ty"
      ];
      default = "pyright";
      description = ''
        Type annotation checker when languages.python.enable is true.
        pyright is the default; ty is Astral's faster beta checker.
      '';
    };

    typescript.bundler = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum bundlers);
      default = null;
      description = ''
        Bundler required when languages.typescript.enable is true.
        One of: vite, turbopack, rspack (legacy webpack apps), tsup, tsdown.
      '';
    };
  };

  config.packages =
    lib.throwIf (project.typescriptBundlerMissing typescriptOn config.typescript.bundler)
      ''
        languages.typescript.enable requires typescript.bundler to be one of:
          ${lib.concatStringsSep " | " bundlers}
        Use rspack for legacy webpack applications.
      ''
      (
        lib.optionals config.python.extensionToolchain [
          pkgs.stdenv.cc
          pkgs.gnumake
          pkgs.pkg-config
          pkgs.rustc
          pkgs.cargo
        ]
      );

  # Toolchains stay off in this repo. Generated monorepos enable them
  # via the Copier questionnaire (devenv.local.nix). That also installs matching Cursor
  # extensions, writes this project's .vscode recommendations/settings,
  # and turns on that language's git-hooks.

  # languages.rust.enable = true;
  # supported.rust.min = "1.80.0";
  # supported.rust.max = "1.85.0";
  # supported.rust.unsupported = [ "1.81.0" ];
  # supported.rust.channels = [ "stable" "beta" ];

  # languages.go.enable = true;
  # supported.go.min = "1.22.0";
  # supported.go.max = "1.24.0";

  # languages.python = {
  #   enable = true;
  #   version = "3.12";
  #   venv.enable = true;
  # };
  # supported.python.min = "3.12";
  # supported.python.max = "3.13";
  # supported.python.implementations = [ "cpython" "pypy" ];
  # python.extensionToolchain = true;
  # pythonTypeChecker = "ty"; # default is pyright; ty is faster (beta)

  # languages.javascript = {
  #   enable = true;
  #   npm.enable = true;
  # };
  # supported.javascript.runtimes = [ "nodejs" ]; # nodejs | bun | deno
  # supported.javascript.nodejs.min = "22";

  # languages.typescript.enable = true;
  # typescript.bundler = "vite"; # required: vite | turbopack | rspack | tsup | tsdown
}
