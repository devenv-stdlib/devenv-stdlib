# Public nix-unit test task surface. The JUnit XML reporter under
# stdlib/private/nix-unit-junit.py is a private implementation detail —
# callers run `nix-unit:test`, never the script. When nix-unit gains native
# JUnit support, swap the module exec and delete the private reporter.
_:
let
  taskId = "nix-unit:test";

  # Store path — only for the devenv module wiring below, not a public API.
  privateReporter = ./private/nix-unit-junit.py;

  # Discover tools|presets/**/tests/unit/default.nix (same rules as
  # tests/lib/discover-suites.nix). Shell-side for `$DEVENV_ROOT` layout.
  # mainSuite: optional path to tests/unit/default.nix when present.
  mkRunScript =
    {
      # NIX_PATH name for the project root (owner suites use <name>/…).
      nixPathRootName,
      junitDir ? "$DEVENV_ROOT/junit",
      includeMain ? true,
    }:
    let
      mainBlock =
        if includeMain then
          ''
            if [ -f "$DEVENV_ROOT/tests/unit/default.nix" ]; then
              run_suite "main" \
                "$DEVENV_ROOT/tests/unit/default.nix" \
                "$DEVENV_ROOT/tests/unit" \
                "$junit_dir/nix-unit.xml"
            fi
          ''
        else
          "";
    in
    ''
      set -euo pipefail
      cd "$DEVENV_ROOT"
      export TERM="''${TERM:-dumb}"
      export PYTHONUNBUFFERED=1

      junit_dir="${junitDir}"
      report="${privateReporter}"
      mkdir -p "$junit_dir"
      status=0
      root_name="${nixPathRootName}"

      list_owner_unit_suites() {
        # Skip `_` prefixes, stop at the first `tests/` directory, only accept
        # its unit/default.nix (do not descend into nested fixture suites).
        while IFS= read -r tests_dir; do
          [ -n "$tests_dir" ] || continue
          f="$tests_dir/unit/default.nix"
          [ -f "$f" ] && printf '%s\n' "$f"
        done < <(
          for root in "$DEVENV_ROOT/tools" "$DEVENV_ROOT/presets"; do
            [ -d "$root" ] || continue
            find "$root" \
              \( -name '_*' -prune \) -o \
              \( -type d -name tests -prune -print \)
          done | sort
        )
      }

      suite_slug() {
        local rel="$1"
        rel="''${rel#/}"
        rel="''${rel%/tests/unit/default.nix}"
        printf '%s' "$rel" | tr '/' '-'
      }

      run_suite() {
        local label="$1" suite="$2" unit_dir="$3" out="$4"
        echo "==> nix-unit ($label)"
        python3 "$report" \
          --quiet \
          --suite "$suite" \
          --unit-dir "$unit_dir" \
          --root "$DEVENV_ROOT" \
          -I "''${root_name}=$DEVENV_ROOT" \
          --output "$out" || status=1
      }

      ${mainBlock}

      while IFS= read -r suite; do
        [ -n "$suite" ] || continue
        rel="''${suite#"$DEVENV_ROOT"/}"
        slug="$(suite_slug "$rel")"
        run_suite "$rel" "$suite" "$(dirname "$suite")" "$junit_dir/nix-unit-$slug.xml"
      done < <(list_owner_unit_suites)

      echo "==> nix-unit junit reports in $junit_dir"
      exit "$status"
    '';

  # Devenv module: packages + `nix-unit:test` task. Imported via stdlib.devenv.load.
  module =
    {
      config,
      lib,
      pkgs,
      options,
      ...
    }:
    let
      cfg = config.stdlib.nixUnit or { };
      enabled = cfg.enable or true;
      # Only wire the task when the host declares options.tasks (devenv).
      hasTasks = options ? tasks;
      rootName =
        if (cfg.nixPathRootName or null) != null && cfg.nixPathRootName != "" then
          cfg.nixPathRootName
        else
          config.name or "project";
      runScript = mkRunScript {
        nixPathRootName = rootName;
        includeMain = cfg.includeMain or true;
      };
    in
    {
      options.stdlib.nixUnit = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Register the `nix-unit:test` task that runs all tools/** and
            presets/** unit suites (plus tests/unit when present) via the
            private JUnit reporter.
          '';
        };
        includeMain = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Also run tests/unit/default.nix when it exists.";
        };
        nixPathRootName = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            `-I NAME=$DEVENV_ROOT` for owner suites that import `<NAME>/…`.
            Defaults to `config.name`.
          '';
        };
      };

      # mkIf alone still registers `tasks` / `scripts` definitions when the
      # condition is false — fixtures that omit options.tasks (e.g.
      # language-matrix) then fail with "The option `tasks' does not exist".
      # Only merge the config attrs when the host declares those options.
      # Stub pkgs in unit evals often omit nix-unit/python3; skip missing attrs.
      config = lib.mkMerge (
        lib.optionals hasTasks [
          (lib.mkIf enabled (
            {
              packages =
                lib.optional (pkgs ? nix-unit) pkgs.nix-unit ++ lib.optional (pkgs ? python3) pkgs.python3;
              tasks.${taskId} = {
                exec = if options ? scripts then "nix-unit-test" else runScript;
                showOutput = true;
              };
            }
            // lib.optionalAttrs (options ? scripts) {
              scripts.nix-unit-test.exec = runScript;
            }
          ))
        ]
      );
    };
in
{
  inherit taskId module;
}
