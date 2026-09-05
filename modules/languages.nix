{
  pkgs,
  lib,
  config,
  ...
}:
let
  typescriptOn = (config.languages.typescript or { }).enable or false;
  bundlers = [
    "vite"
    "turbopack"
    "rspack"
    "tsup"
    "tsdown"
  ];
in
{
  options.python.extensionToolchain = lib.mkEnableOption ''
    C, C++, and Rust compilers so pip/uv can build Python extensions from
    source when wheels or Homebrew bottles are missing. Does not enable
    languages.c, languages.cplusplus, or languages.rust
  '';

  options.typescript.bundler = lib.mkOption {
    type = lib.types.nullOr (lib.types.enum bundlers);
    default = null;
    description = ''
      Bundler required when languages.typescript.enable is true.
      One of: vite, turbopack, rspack (legacy webpack apps), tsup, tsdown.
    '';
  };

  config.packages =
    lib.throwIf (typescriptOn && config.typescript.bundler == null)
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

  # Toolchains stay off in this repo. Enabling a language here (or in
  # devenv.local.nix) installs matching Cursor/VS Code extensions if they
  # are missing, writes this project's .vscode recommendations/settings,
  # and turns on that language's git-hooks.

  # languages.rust.enable = true;

  # languages.go.enable = true;

  # languages.python = {
  #   enable = true;
  #   version = "3.12";
  #   venv.enable = true;
  # };
  # python.extensionToolchain = true;

  # languages.javascript = {
  #   enable = true;
  #   npm.enable = true;
  # };

  # languages.typescript.enable = true;
  # typescript.bundler = "vite"; # required: vite | turbopack | rspack | tsup | tsdown
}
