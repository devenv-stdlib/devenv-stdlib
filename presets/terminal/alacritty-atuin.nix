# Atuin (+ ble.sh on bash). Shell option is mandatory unless exactly one shell tool is on.
{ lib, ... }:
let
  presetLib = import ../../stdlib/preset.nix { inherit lib; };
  inherit (presetLib) mkPreset normalizeTool;
  shell = import ../../stdlib/shell.nix { inherit lib; };

  resolvedOf = cfg: shell.resolve cfg cfg.presets.terminal.alacritty-atuin.shell;

  # Shell leaf names stay strings for shell.policyShells; wrap as attrpath segments.
  shellPath = name: [
    "shell"
    name
  ];

  toolsFor =
    cfg:
    let
      resolved = resolvedOf cfg;
      shells = map shellPath (shell.policyShells cfg resolved);
    in
    shells
    ++ [
      [
        "shell"
        "history"
        "atuin"
      ]
    ]
    ++ lib.optional (shell.shouldInstallBlesh resolved) [
      "shell"
      "blesh"
    ];

  namesOf = cfg: map (t: (normalizeTool t).name) (toolsFor cfg);
in
{
  imports = [
    (mkPreset {
      path = [
        "terminal"
        "alacritty-atuin"
      ];
      description = "Atuin history with daemon fuzzy search; ble.sh before Atuin/Starship when the resolved shell is bash.";

      extraOptions.shell = shell.mkShellOption {
        description = "Interactive shell this preset configures. Required unless exactly one of tools.{bash,zsh,elvish} is enabled.";
      };

      tools = toolsFor;

      requires = [
        {
          assertion = cfg: resolvedOf cfg != null;
          message = "presets.terminal.alacritty-atuin.shell is required unless exactly one of tools.{bash,zsh,elvish} is enabled";
        }
        {
          assertion = cfg: builtins.elem "atuin" (namesOf cfg);
          message = "terminal.alacritty-atuin requires the atuin tool";
        }
        {
          assertion =
            cfg: !(shell.shouldInstallBlesh (resolvedOf cfg)) || builtins.elem "blesh" (namesOf cfg);
          message = "terminal.alacritty-atuin requires blesh when the resolved shell is bash";
        }
      ];

      configure = cfg: {
        shell.preferred = resolvedOf cfg;
      };

      homeManager =
        {
          pkgs,
          lib,
          config,
          ...
        }:
        let
          resolved = resolvedOf config;
          shells = shell.policyShells config resolved;
          integrations = shell.enableIntegrations shells;
          installBlesh = shell.shouldInstallBlesh resolved;
        in
        {
          programs.atuin = {
            enable = true;
            inherit (integrations) enableBashIntegration enableZshIntegration;
            # User systemd + socket activation (generic Linux). Do not set
            # settings.daemon.autostart: it is incompatible with systemd_socket.
            daemon.enable = true;
            forceOverwriteSettings = true;
            settings.search_mode = "daemon-fuzzy";
          };

          # ble.sh before Atuin/Starship — bash only.
          programs.bash.initExtra = lib.mkIf installBlesh (
            lib.mkBefore ''
              source -- "${pkgs.blesh}/share/blesh/ble.sh"
            ''
          );

          home.packages = lib.mkIf installBlesh [ pkgs.blesh ];

          xdg.configFile."blesh/init.sh" = lib.mkIf installBlesh {
            text = ''
              bleopt highlight_syntax=on
            '';
          };

          # Elvish: this HM pin has no programs.elvish integration toggle.
          xdg.configFile."elvish/lib/atuin.elv" = lib.mkIf (builtins.elem "elvish" shells) {
            text = ''
              eval (atuin init elvish | slurp)
            '';
          };
        };
    })
  ];
}
