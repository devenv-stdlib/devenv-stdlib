{ pkgs, ... }:
{
  packages = [
    pkgs.nix-unit
    pkgs.act
  ];

  scripts.test-devenv.exec = ''
    set -euo pipefail
    cd "$DEVENV_ROOT"
    case ":''${NIX_PATH:-}:" in
      *:nixpkgs=*) ;;
      *) export NIX_PATH="nixpkgs=flake:nixpkgs''${NIX_PATH:+:$NIX_PATH}" ;;
    esac

    echo "==> nix-unit"
    nix-unit -I nixpkgs=flake:nixpkgs "$DEVENV_ROOT/tests/unit/default.nix"

    echo "==> bats"
    bats --print-output-on-failure --recursive "$DEVENV_ROOT/tests"

    echo "==> nixosTest"
    nix-build --no-out-link "$DEVENV_ROOT/tests/integration/default.nix"

    echo "==> generate test.yml"
    sync-language-versions-workflow

    if [ -f "$DEVENV_ROOT/.github/workflows/test.yml" ]; then
      if [ -n "''${GITHUB_ACTIONS:-}" ] || [ -n "''${ACT:-}" ]; then
        echo "skip act on generated test.yml (already inside GitHub Actions or act)"
      else
        echo "==> act .github/workflows/test.yml"
        command -v docker >/dev/null
        act workflow_call \
          -W "$DEVENV_ROOT/.github/workflows/test.yml" \
          -P ubuntu-22.04=ghcr.io/catthehacker/ubuntu:act-22.04
      fi
    fi
  '';

  tasks."devenv:test-devenv".exec = "test-devenv";
}
