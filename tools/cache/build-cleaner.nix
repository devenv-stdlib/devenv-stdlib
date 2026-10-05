# build-cleaner: multi-ecosystem build artifact / cache cleaner — Home Manager
# / global leaf. Repository-local enable is the thin preset's project payload
# (presets/cache/build-cleaner.nix scope = "local"), not a dual mkTool payload.
# Release pin lives here (install.kind = binary); stdlib/binary.nix builds it.
# Upstream: https://github.com/moinsen-dev/build_cleaner
args@{
  pkgs,
  lib,
  config,
  ...
}:
if false then
  { inherit pkgs config; }
else
  let
    tool = import ../../stdlib/tool.nix { inherit lib; };
    binary = import ../../stdlib/binary.nix { inherit lib; };

    release = binary.fromGithubRelease {
      pname = "build-cleaner";
      version = "0.4.0";
      owner = "moinsen-dev";
      repo = "build_cleaner";
      bin = "build-cleaner";
      archives = {
        x86_64-linux = {
          archive = "build-cleaner-x86_64-unknown-linux-gnu.tar.gz";
          hash = "sha256-gq5wzjQTrEUDXYe+UzRY+RT0yVbbYbyOcHj+RdVZYZs=";
        };
        aarch64-linux = {
          archive = "build-cleaner-aarch64-unknown-linux-gnu.tar.gz";
          hash = "sha256-i9asOA+a7MYpeegADb0kodEvhabJJRRFLCq1sG6wxQ4=";
        };
        x86_64-darwin = {
          archive = "build-cleaner-x86_64-apple-darwin.tar.gz";
          hash = "sha256-wcBoFdjd5hnqJg5x2J0qgKvzCszBaCv2Vi7SX8IdWKQ=";
        };
        aarch64-darwin = {
          archive = "build-cleaner-aarch64-apple-darwin.tar.gz";
          hash = "sha256-60pDcyECEs5+lJqWIppFhbq+9xQgedm1CsvCQqi/9Zw=";
        };
      };
      # Prebuilt ELF links libgcc_s (not only libc).
      extraBuildInputs = pkgs': [ pkgs'.stdenv.cc.cc.lib ];
      meta = {
        description = "Recursively find and delete build artifacts and caches";
        license = lib.licenses.mit;
      };
    };

    # Tests may stub pkgs.build-cleaner; real evals use the GitHub release.
    package = pkgs': pkgs'.build-cleaner or (release pkgs');
  in
  tool.binaryLeaf args {
    name = "build-cleaner";
    category = "cache";
    defaultEnable = false;
    inherit package;
    # Declared devenv tasks (presets export when local scope is on).
    # Interactive `build-cleaner` (prompts) is not a task; use dry-run / script.
    tasks =
      { pkgs, ... }:
      let
        bc = package pkgs;
        bin = if builtins.isAttrs bc && bc ? outPath then "${bc}/bin/build-cleaner" else "build-cleaner";
      in
      {
        dry-run = {
          exec = ''
            set -euo pipefail
            ${bin} --dry-run
          '';
        };
      };
  }
