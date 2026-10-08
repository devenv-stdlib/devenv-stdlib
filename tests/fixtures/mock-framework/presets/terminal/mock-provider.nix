# extraOptions must become module options. Tool selection reads them
# (presets.terminal.quake.provider) while realize runs.
{ lib, ... }:
{
  path = [
    "terminal"
    "mock-provider"
  ];
  description = "Mock preset whose tool selection reads an extra option.";
  extraOptions.provider = lib.mkOption {
    type = lib.types.str;
    default = "alacritty";
  };
  tools =
    cfg:
    assert cfg.presets.terminal.mock-provider.provider == "alacritty";
    [ ];
}
