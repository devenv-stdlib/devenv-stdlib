_: {
  name = "devenv";

  cachix.pull = [ "devenv" ];

  enterShell = ''
    echo "devenv ready: ''${USER:-unknown}@$(uname -n)"
  '';

  enterTest = ''
    set -euo pipefail
    command -v git
    command -v gh
    command -v jq
    command -v rg
    command -v fd
    command -v direnv
    command -v nixfmt
    git --version
    jq --version
  '';
}
