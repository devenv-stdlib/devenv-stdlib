_: {
  name = "devenv";

  cachix.pull = [ "devenv" ];

  enterShell = ''
    echo "devenv ready: ''${USER:-unknown}@$(uname -n)"

    # Git has no pre-tag hook, so the tag guard lives in reference-transaction,
    # which prek does not manage. Refresh it on every shell entry.
    hooks_dir=$(git rev-parse --git-path hooks 2>/dev/null || true)
    if [ -n "$hooks_dir" ] && [ -f "$DEVENV_ROOT/hooks/reference-transaction" ]; then
      mkdir -p "$hooks_dir"
      install -m 755 "$DEVENV_ROOT/hooks/reference-transaction" "$hooks_dir/reference-transaction"
    fi
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
    command -v bats
    command -v shellcheck
    command -v starship
    command -v warp-terminal
    git --version
    jq --version
    bats --print-output-on-failure --recursive "$DEVENV_ROOT/tests"
  '';
}
