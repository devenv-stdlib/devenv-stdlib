# First-class linters.* options — parallel to languages.*.
# Treefmt-backed entries lower into devenv's treefmt integration:
#   https://devenv.sh/integrations/treefmt/
# Prek-backed entries are defined in modules/hooks/common.nix and gated here.
{
  lib,
  config,
  ...
}:
let
  lintersLib = import ../../stdlib/linters.nix { inherit lib; };
  cfg = config.linters;

  treefmtEnabled = lib.any (name: cfg.${name}.enable) (builtins.attrNames lintersLib.treefmt);

  treefmtPrograms = lib.mkMerge (
    lib.mapAttrsToList (
      name: meta:
      lib.mkIf cfg.${name}.enable {
        ${meta.program} = {
          enable = true;
        }
        // lib.optionalAttrs (name == "yamlfmt") {
          # Nested under the program — do not `//` a sibling yamlfmt.settings
          # attrset or it replaces `{ enable = true; }` entirely.
          settings = {
            gitignore_excludes = true;
            exclude = [ ".pre-commit-config.yaml" ];
            formatter = {
              type = "basic";
              retain_line_breaks_single = true;
            };
          };
        };
      }
    ) lintersLib.treefmt
  );
in
{
  options.linters = lib.mapAttrs (
    _name: meta:
    {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = meta.defaultEnable;
        description = meta.description + " Backend: ${meta.backend}.";
      };
    }
    // lib.optionalAttrs (meta.backend == "treefmt") {
      # Escape hatch for treefmt-nix program settings (edition, package, …).
      settings = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
        description = "Extra attributes merged into treefmt.config.programs.${meta.program}.";
      };
    }
  ) lintersLib.catalog;

  config = lib.mkMerge [
    {
      # devenv treefmt integration (requires treefmt-nix input in devenv.yaml).
      treefmt.enable = lib.mkDefault treefmtEnabled;

      # One git-hooks entry runs the whole treefmt suite (same wrapper as `treefmt`).
      git-hooks.hooks.treefmt.enable = lib.mkIf config.treefmt.enable true;

      # Vendored upstream skills — not ours to reflow (matches former git-hooks.excludes).
      # Also ignore stray relative Nix stores (bad XDG_CACHE_HOME) and build products.
      treefmt.config.settings.global.excludes = [
        ".agents/skills/*"
        ".devenv/*"
        ".git/*"
        ".pre-commit-config.yaml"
        "nix/**"
        "result"
        "result-*"
        "junit/**"
      ];

      # devenv schedules treefmt before enterShell by default; that rewrites the
      # whole tree on every shell. Opt into explicit `treefmt` / prek instead.
      tasks."devenv:treefmt:run".exec = lib.mkForce "true";
    }

    (lib.mkIf config.treefmt.enable {
      treefmt.config.programs = lib.mkMerge (
        [
          treefmtPrograms
        ]
        ++ lib.mapAttrsToList (
          name: meta:
          lib.mkIf (cfg.${name}.enable && cfg.${name}.settings != { }) {
            ${meta.program} = cfg.${name}.settings;
          }
        ) lintersLib.treefmt
      );
    })
  ];
}
