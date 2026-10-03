# Compat stub (Phase 4 cutover). Home Manager no longer evaluates this file.
#
# Supported Ubuntu hosts use Den:
#   home-switch  →  home-manager switch --flake .#developer --impure
# Composition lives in modules/den/homes.nix + modules/aspects/* (cursor, terminal, home-cli).
# Optional host overrides: home.local.nix (imported by den.homes).
#
# Kept as a path so Copier destinations still receive a recognizable filename;
# do not pass `-f home.nix` — that path is unsupported after cutover.
{
  assertions = [
    {
      assertion = false;
      message = ''
        Legacy home.nix root removed (Den Phase 4 cutover).
        Use `home-switch` (flake #developer --impure) or:
          home-manager switch -b backup --flake .#developer --impure
      '';
    }
  ];
}
