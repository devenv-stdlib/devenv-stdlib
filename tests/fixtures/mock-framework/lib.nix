# Shared imports for mock tool/preset files under this fixture tree.
{ lib }:
{
  tool = import ../../../stdlib/tool.nix { inherit lib; };
  # Presets import this for path helpers when needed.
  preset = import ../../../stdlib/preset.nix { inherit lib; };
}
