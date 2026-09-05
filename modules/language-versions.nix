{
  pkgs,
  lib,
  config,
  ...
}:
let
  versions = import ./language-versions-lib.nix { inherit lib; };

  langOn = name: (config.languages.${name} or { }).enable or false;
  pythonOn = langOn "python";
  rustOn = langOn "rust";
  goOn = langOn "go";
  javascriptOn = langOn "javascript" || langOn "typescript";

  versionPolicy =
    extra:
    {
      min = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Minimum supported version (required when the language is enabled).";
      };
      max = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional maximum supported version.";
      };
      unsupported = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Versions between min and max that must not be used (for example a Rust ICE).";
      };
      versions = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Versions to test in CI. Defaults to min and max (if set), minus unsupported.";
      };
    }
    // extra;

  snapshot = {
    inherit
      pythonOn
      rustOn
      goOn
      javascriptOn
      ;
    inherit (config.supported)
      python
      rust
      go
      javascript
      ;
  };

  problemList = versions.problems snapshot;

  workflowFile = lib.throwIf (problemList != [ ]) (lib.concatStringsSep "\n" problemList) (
    pkgs.writeText "test.yml" (versions.workflowText snapshot)
  );
in
{
  options.supported = {
    python = lib.mkOption {
      type = lib.types.submodule {
        options = versionPolicy {
          implementations = lib.mkOption {
            type = lib.types.listOf (lib.types.enum versions.pythonImpls);
            default = [ "cpython" ];
            description = "Python 3 implementations to test. cpython and/or pypy.";
          };
        };
      };
      default = { };
    };
    rust = lib.mkOption {
      type = lib.types.submodule {
        options = versionPolicy {
          channels = lib.mkOption {
            type = lib.types.listOf (lib.types.enum versions.rustChannels);
            default = [ "stable" ];
            description = "Rust channels. stable is required; beta and nightly are optional extras.";
          };
        };
      };
      default = { };
    };
    go = lib.mkOption {
      type = lib.types.submodule { options = versionPolicy { }; };
      default = { };
    };
    javascript = lib.mkOption {
      type = lib.types.submodule {
        options = {
          runtimes = lib.mkOption {
            type = lib.types.listOf (lib.types.enum versions.jsRuntimes);
            default = [ ];
            description = "JS runtimes when javascript or typescript is on: nodejs, bun, deno.";
          };
          nodejs = lib.mkOption {
            type = lib.types.submodule { options = versionPolicy { }; };
            default = { };
          };
          bun = lib.mkOption {
            type = lib.types.submodule { options = versionPolicy { }; };
            default = { };
          };
          deno = lib.mkOption {
            type = lib.types.submodule { options = versionPolicy { }; };
            default = { };
            description = "Deno runtime version policy (languages.deno).";
          };
        };
      };
      default = { };
    };
  };

  config = {
    scripts.sync-language-versions-workflow.exec = ''
      set -euo pipefail
      dest="$DEVENV_ROOT/.github/workflows/test.yml"
      mkdir -p "$(dirname "$dest")"
      tmp="$(mktemp)"
      cp ${lib.escapeShellArg workflowFile} "$tmp"
      if ! cmp -s "$tmp" "$dest" 2>/dev/null; then
        mv "$tmp" "$dest"
        echo "wrote .github/workflows/test.yml"
      else
        rm -f "$tmp"
      fi
    '';

    enterShell = ''
      sync-language-versions-workflow
    '';
  };
}
