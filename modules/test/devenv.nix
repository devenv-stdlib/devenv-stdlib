{ pkgs, ... }:
{
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

    test-devenv.exec = ''
      set -euo pipefail
      cd "$DEVENV_ROOT"
      # shellcheck disable=SC1091
      . "$DEVENV_ROOT/home/nix-path.sh"
      ensure_nixpkgs_on_nix_path

      # devenv tasks and act have no TTY; tput/pretty-bats SIGPIPE without TERM.
      export TERM="''${TERM:-dumb}"
      # junit-report.py tees nix-unit to STDOUT; keep that line-buffered under pipes.
      export PYTHONUNBUFFERED=1

      junit_dir="$DEVENV_ROOT/junit"
      report="$DEVENV_ROOT/tests/junit-report.py"
      rm -rf "$junit_dir"
      mkdir -p "$junit_dir"
      status=0

      echo "==> nix-unit"
      python3 "$report" nix-unit \
        --suite "$DEVENV_ROOT/tests/unit/default.nix" \
        --unit-dir "$DEVENV_ROOT/tests/unit" \
        --root "$DEVENV_ROOT" \
        --output "$junit_dir/nix-unit.xml" || status=1

      echo "==> bats"
      # GNU parallel prompts once for a citation; silence that in CI/noninteractive.
      mkdir -p "''${HOME}/.parallel"
      touch "''${HOME}/.parallel/will-cite"
      bats_jobs="$(nproc 2>/dev/null || echo 2)"
      # tap + report-formatter: pretty writes to a pipe and bats-format-junit
      # exits 141 (SIGPIPE) when stdout is not a TTY (CI, act, devenv tasks).
      if bats --jobs "$bats_jobs" --formatter tap --report-formatter junit --output "$junit_dir" \
        --print-output-on-failure --recursive "$DEVENV_ROOT/tests"; then
        :
      else
        status=1
      fi
      if [ ! -s "$junit_dir/report.xml" ]; then
        # Still stream progress to the log: capture for JUnit and mirror to STDOUT.
        bats --jobs "$bats_jobs" --formatter junit --recursive "$DEVENV_ROOT/tests" \
          | tee "$junit_dir/report.xml" || status=1
      fi
      python3 "$report" enrich-bats \
        --input "$junit_dir/report.xml" \
        --output "$junit_dir/bats.xml" \
        --root "$DEVENV_ROOT" || true
      rm -f "$junit_dir/report.xml"

      echo "==> nixosTest"
      # CI runners (+ nested act) share limited disk; keep integration builds serial.
      # Locally, parallelize dependency builds with nproc.
      if [ -n "''${GITHUB_ACTIONS:-}" ] || [ -n "''${CI:-}" ]; then
        nix_jobs=1
      else
        nix_jobs="$(nproc 2>/dev/null || echo auto)"
      fi
      if [ -n "''${ACT:-}" ]; then
        echo "skip nixosTest inside act (no /dev/kvm in the act container)"
        python3 "$report" nixos-test \
          --skipped \
          --status 0 \
          --root "$DEVENV_ROOT" \
          --output "$junit_dir/nixos-test.xml" || true
      elif nix-build -j "$nix_jobs" --no-out-link "$DEVENV_ROOT/tests/integration/default.nix" 2>&1 | tee "$junit_dir/nixos-test.log"; then
        python3 "$report" nixos-test \
          --status 0 \
          --log "$junit_dir/nixos-test.log" \
          --root "$DEVENV_ROOT" \
          --output "$junit_dir/nixos-test.xml" || true
      else
        status=1
        python3 "$report" nixos-test \
          --status 1 \
          --log "$junit_dir/nixos-test.log" \
          --root "$DEVENV_ROOT" \
          --output "$junit_dir/nixos-test.xml" || true
      fi

      echo "==> junit reports in $junit_dir"

      echo "==> generate test.yml"
      sync-language-versions-workflow

      echo "==> actionlint generated workflows"
      fixtures="$(nix-build -j "$nix_jobs" --no-out-link "$DEVENV_ROOT/tests/integration/workflows.nix")"
      mkdir -p "$junit_dir/workflows"
      cp -L "$fixtures"/*.yml "$junit_dir/workflows/"
      if [ -f "$DEVENV_ROOT/.github/workflows/test.yml" ]; then
        actionlint -config-file "$DEVENV_ROOT/.github/actionlint.yaml" \
          "$DEVENV_ROOT/.github/workflows/test.yml" || status=1
      fi
      actionlint -config-file "$DEVENV_ROOT/.github/actionlint.yaml" \
        "$junit_dir/workflows"/*.yml || status=1

      if [ -n "''${ACT:-}" ]; then
        echo "skip act (already inside act)"
      elif [ "$status" -ne 0 ]; then
        echo "skip act (suite already failed)"
      else
        command -v docker >/dev/null
        echo "==> act image"
        build-act-image
        docker volume create devenv-act-nix >/dev/null
        docker volume create devenv-act-nix-cache >/dev/null
        # Fresh volumes are root-owned; install-nix single-user needs the act UID.
        docker run --rm --user 0 \
          -v devenv-act-nix:/nix \
          -v devenv-act-nix-cache:/home/runner/.cache/nix \
          devenv-act:24.04 \
          chown -R "$(id -u):$(id -g)" /nix /home/runner/.cache/nix
        # TMPDIR/RUNNER_TEMP: install-nix-action uses set -u and expands RUNNER_TEMP
        # when TMPDIR is unset (cachix/install-nix-action#197).
        act_opts="--user runner --env HOME=/home/runner --env TMPDIR=/tmp --env RUNNER_TEMP=/tmp --env RUNNER_TOOL_CACHE=/tmp/toolcache -v devenv-act-nix:/nix -v devenv-act-nix-cache:/home/runner/.cache/nix"
        # act --concurrent-jobs 1 still overlapped matrix cells on the shared /nix
        # volume (ENOSPC). Run each listed job id with -j so only one cell fills it.
        run_act_serial() {
          local workflow=$1
          local job
          while read -r job; do
            [ -n "$job" ] || continue
            echo "==> act -j $job ($workflow)"
            act workflow_call \
              --pull=false \
              --concurrent-jobs 1 \
              --container-options "$act_opts" \
              -j "$job" \
              -W "$workflow" \
              -P ubuntu-24.04=devenv-act:24.04 \
              -P ubuntu-26.04=devenv-act:24.04 || return 1
          done < <(
            act -W "$workflow" -l --pull=false \
              -P ubuntu-24.04=devenv-act:24.04 \
              -P ubuntu-26.04=devenv-act:24.04 2>/dev/null \
              | awk 'NR > 1 && $2 != "" && $2 != "ID" { print $2 }' | sort -u
          )
        }
        if [ -z "''${GITHUB_ACTIONS:-}" ] && [ -f "$DEVENV_ROOT/.github/workflows/test.yml" ]; then
          echo "==> act .github/workflows/test.yml"
          run_act_serial "$DEVENV_ROOT/.github/workflows/test.yml" || status=1
        fi
        echo "==> act generated python matrix"
        run_act_serial "$junit_dir/workflows/python.yml" || status=1
      fi

      exit "$status"
    '';
  };

  tasks."devenv:test-devenv" = {
    exec = "test-devenv";
    # devenv tasks capture stdout by default; stream it live in CI / non-TTY.
    showOutput = true;
  };
}
