{ pkgs, ... }:
{
  imports = [
    ./unit.nix
    ./integration.nix
  ];

  packages = [
    pkgs.nix-unit
    pkgs.act
    pkgs.actionlint
    pkgs.python3
  ];

  scripts = {
    refresh-toolchain-latest.exec = ''
      set -euo pipefail
      python3 "$DEVENV_ROOT/includes/toolchain-latest.py" refresh
    '';

    docs-dev.exec = ''
      set -euo pipefail
      cd "$DEVENV_ROOT/docs"
      if [ ! -d node_modules ]; then
        npm ci
      fi
      npm run dev -- --host
    '';

    docs-build.exec = ''
      set -euo pipefail
      cd "$DEVENV_ROOT/docs"
      npm ci
      npm run build
    '';

    build-act-image.exec = ''
      set -euo pipefail
      docker build \
        --build-arg UID="$(id -u)" \
        --build-arg GID="$(id -g)" \
        -t devenv-act:24.04 \
        "$DEVENV_ROOT/tests/act"
    '';

    # Local entrypoint: unit suite, then integration (same gate as CI).
    test-devenv.exec = ''
      set -euo pipefail
      rm -rf "$DEVENV_ROOT/junit"
      mkdir -p "$DEVENV_ROOT/junit"
      status=0
      test-devenv-unit || status=1
      if [ "$status" -ne 0 ]; then
        echo "skip integration (unit suite failed)"
        exit "$status"
      fi
      test-devenv-integration || status=1
      exit "$status"
    '';
  };

  tasks."devenv:test-devenv" = {
    exec = "test-devenv";
    showOutput = true;
  };
}
