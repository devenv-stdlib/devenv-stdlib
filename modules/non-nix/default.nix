# Non-Nix catalog editors (add/remove [[tool]] entries).
_: {
  scripts = {
    "non-nix:add-local".exec = ''
      set -euo pipefail
      exec bash "$DEVENV_ROOT/modules/non-nix/edit-catalog.sh" add-local "$@"
    '';
    "non-nix:remove-local".exec = ''
      set -euo pipefail
      exec bash "$DEVENV_ROOT/modules/non-nix/edit-catalog.sh" remove-local "$@"
    '';
    "non-nix:add".exec = ''
      set -euo pipefail
      exec bash "$DEVENV_ROOT/modules/non-nix/edit-catalog.sh" add "$@"
    '';
    "non-nix:remove".exec = ''
      set -euo pipefail
      exec bash "$DEVENV_ROOT/modules/non-nix/edit-catalog.sh" remove "$@"
    '';
  };

  tasks = {
    "non-nix:add-local".exec = ''
      set -euo pipefail
      exec bash "$DEVENV_ROOT/modules/non-nix/edit-catalog.sh" add-local "$@"
    '';
    "non-nix:remove-local".exec = ''
      set -euo pipefail
      exec bash "$DEVENV_ROOT/modules/non-nix/edit-catalog.sh" remove-local "$@"
    '';
    "non-nix:add".exec = ''
      set -euo pipefail
      exec bash "$DEVENV_ROOT/modules/non-nix/edit-catalog.sh" add "$@"
    '';
    "non-nix:remove".exec = ''
      set -euo pipefail
      exec bash "$DEVENV_ROOT/modules/non-nix/edit-catalog.sh" remove "$@"
    '';
  };
}
