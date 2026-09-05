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
    command -v home-manager
    command -v debtmap
    git --version
    jq --version
    bats --print-output-on-failure --recursive "$DEVENV_ROOT/tests"
  '';

  scripts.home-switch.exec = ''
    # Flakes-only hosts often have no <nixpkgs> on NIX_PATH; home-manager -f
    # needs it. Keep a user-supplied nixpkgs= entry; otherwise set or prepend
    # nixpkgs=flake:nixpkgs.
    if [ -z "''${NIX_PATH:-}" ]; then
      export NIX_PATH=nixpkgs=flake:nixpkgs
    else
      rest="''${NIX_PATH}"
      has_nixpkgs=0
      while [ -n "$rest" ]; do
        entry="''${rest%%:*}"
        rest="''${rest#"$entry"}"
        rest="''${rest#:}"
        case "$entry" in
          nixpkgs=*) has_nixpkgs=1; break ;;
        esac
      done
      if [ "$has_nixpkgs" -eq 0 ]; then
        export NIX_PATH="nixpkgs=flake:nixpkgs:''${NIX_PATH}"
      fi
    fi
    home-manager switch -b backup -f "$DEVENV_ROOT/home.nix" "$@"
  '';
}
