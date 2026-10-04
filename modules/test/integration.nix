_: {

  scripts.test-devenv-integration.exec = ''
    set -euo pipefail
    cd "$DEVENV_ROOT"
    # shellcheck disable=SC1091
    . "$DEVENV_ROOT/home/nix-path.sh"
    ensure_nixpkgs_on_nix_path

    # devenv tasks and act have no TTY; tput/pretty-bats SIGPIPE without TERM.
    export TERM="''${TERM:-dumb}"
    export PYTHONUNBUFFERED=1

    junit_dir="$DEVENV_ROOT/junit"
    report="$DEVENV_ROOT/tests/junit-report.py"
    mkdir -p "$junit_dir"
    status=0

    echo "==> nixosTest"
    # Dedicated integration job (after the unit gate): parallelize dependency builds.
    nix_jobs="$(nproc 2>/dev/null || echo auto)"
    nixos_log="$junit_dir/nixos-test.log"
    if [ -n "''${ACT:-}" ]; then
      echo "skip nixosTest inside act (no /dev/kvm in the act container)"
      python3 "$report" nixos-test \
        --skipped \
        --status 0 \
        --root "$DEVENV_ROOT" \
        --output "$junit_dir/nixos-test.xml" || true
    elif nix-build -j "$nix_jobs" --no-out-link "$DEVENV_ROOT/tests/integration/default.nix" \
      >"$nixos_log" 2>&1; then
      echo "==> nixosTest: ok"
      python3 "$report" nixos-test \
        --status 0 \
        --log "$nixos_log" \
        --root "$DEVENV_ROOT" \
        --output "$junit_dir/nixos-test.xml" || true
    else
      status=1
      echo "==> nixosTest: FAILED"
      cat "$nixos_log"
      python3 "$report" nixos-test \
        --status 1 \
        --log "$nixos_log" \
        --root "$DEVENV_ROOT" \
        --output "$junit_dir/nixos-test.xml" || true
    fi

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
      # act --concurrent-jobs 1 only bounds whole jobs: every matrix cell of a job
      # still starts at once on the shared /nix volume (ENOSPC, `chown -R /nix`
      # racing another cell's install-nix). Enumerate cells from a dry run and
      # pin every matrix key so each act invocation runs exactly one cell.
      # Require a non-empty matrix object — a bare jobID line would re-expand
      # every cell in parallel.
      run_act_serial() {
        local workflow=$1
        local job filters
        local act_log
        local cells
        cells="$(
          act workflow_call -W "$workflow" -n --json --pull=false \
            -P ubuntu-24.04=devenv-act:24.04 \
            -P ubuntu-26.04=devenv-act:24.04 2>/dev/null \
            | jq -r 'select(.jobID != null and ((.matrix // {}) | length) > 0)
                | [.jobID, (.matrix | to_entries | map("--matrix=\(.key):\(.value)") | join(" "))]
                | join(" ")' \
            | sort -u
        )"
        if [ -z "$cells" ]; then
          # Matrix-less jobs (e.g. no-language-matrix fixtures): one -j per id.
          cells="$(
            act -W "$workflow" -l --pull=false \
              -P ubuntu-24.04=devenv-act:24.04 \
              -P ubuntu-26.04=devenv-act:24.04 2>/dev/null \
              | awk 'NR > 1 && $2 != "" && $2 != "ID" { print $2 }' | sort -u
          )"
        fi
        while read -r job filters; do
          [ -n "$job" ] || continue
          act_log="$junit_dir/act-$job.log"
          echo "==> act -j $job $filters ($workflow)"
          # shellcheck disable=SC2086
          if act workflow_call \
            --pull=false \
            --concurrent-jobs 1 \
            --container-options "$act_opts" \
            -j "$job" $filters \
            -W "$workflow" \
            -P ubuntu-24.04=devenv-act:24.04 \
            -P ubuntu-26.04=devenv-act:24.04 \
            >"$act_log" 2>&1; then
            echo "==> act -j $job: ok"
          else
            echo "==> act -j $job: FAILED"
            cat "$act_log"
            return 1
          fi
        done <<< "$cells"
      }
      if [ -z "''${GITHUB_ACTIONS:-}" ] && [ -f "$DEVENV_ROOT/.github/workflows/test.yml" ]; then
        echo "==> act .github/workflows/test.yml"
        run_act_serial "$DEVENV_ROOT/.github/workflows/test.yml" || status=1
      fi
      echo "==> act generated python matrix"
      run_act_serial "$junit_dir/workflows/python.yml" || status=1
    fi

    echo "==> integration junit reports in $junit_dir"
    exit "$status"
  '';

  tasks."devenv:test-devenv-integration" = {
    exec = "test-devenv-integration";
    showOutput = true;
  };
}
