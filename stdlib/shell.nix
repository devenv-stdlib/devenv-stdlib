# Interactive shell tools (bash / zsh / elvish) and preferred-shell resolution.
# Shell-related presets expose a `shell` option that uses these helpers.
# ble.sh is bash-only: install/load only when the resolved shell is bash.
{ lib }:
let
  knownShells = [
    "bash"
    "zsh"
    "elvish"
  ];

  enabledShells =
    config: lib.filter (name: (config.tools.${name} or { }).enable or false) knownShells;

  # Sole enabled shell tool, or null when zero or more than one are on.
  soleEnabled =
    config:
    let
      enabled = enabledShells config;
    in
    if builtins.length enabled == 1 then builtins.head enabled else null;

  # Prefer an explicit option value; otherwise the sole enabled shell tool.
  # null means the caller must treat the option as mandatory.
  resolve = config: value: if value != null then value else soleEnabled config;

  # With multiple shell tools enabled, apply integrations to every enabled
  # shell. With none enabled, fall back to the resolved preferred shell.
  policyShells =
    config: resolved:
    let
      enabled = enabledShells config;
    in
    if enabled != [ ] then enabled else lib.optional (resolved != null) resolved;

  shouldInstallBlesh = resolved: resolved == "bash";

  # Home Manager integration flags for tools that speak bash/zsh (and elvish
  # via a manual init snippet where the program module has no toggle).
  enableIntegrations = shells: {
    enableBashIntegration = builtins.elem "bash" shells;
    enableZshIntegration = builtins.elem "zsh" shells;
  };

  shellType = lib.types.nullOr (lib.types.enum knownShells);

  # Preset option: mandatory unless exactly one shell tool is enabled.
  mkShellOption =
    {
      description ? "Interactive shell this preset configures. Required unless exactly one of tools.{bash,zsh,elvish} is enabled.",
    }:
    lib.mkOption {
      type = shellType;
      default = null;
      inherit description;
    };

  # Top-level shared preferred shell (tools read this when no preset option).
  preferredOption = lib.mkOption {
    type = shellType;
    default = null;
    description = "Preferred interactive shell. Defaults to the sole enabled shell tool when only one of bash/zsh/elvish is on.";
  };

  # Assertion for shell-needing modules: option optional iff one shell tool is on.
  requireResolved =
    {
      config,
      value,
      message,
    }:
    {
      assertion = resolve config value != null;
      inherit message;
    };

  # Home Manager fragment: defines options.shell.preferred.
  hmModule = {
    options.shell.preferred = preferredOption;
  };
in
{
  inherit
    knownShells
    enabledShells
    soleEnabled
    resolve
    policyShells
    shouldInstallBlesh
    enableIntegrations
    shellType
    mkShellOption
    preferredOption
    requireResolved
    hmModule
    ;

  category = "shell";
  toolPath = name: "tools/shell/${name}.nix";
}
