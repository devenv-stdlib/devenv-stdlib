_: {

  scripts.test-devenv-unit.exec = ''
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
    mkdir -p "$junit_dir"
    status=0

    echo "==> nix-unit"
    python3 "$report" nix-unit \
      --quiet \
      --suite "$DEVENV_ROOT/tests/unit/default.nix" \
      --unit-dir "$DEVENV_ROOT/tests/unit" \
      --root "$DEVENV_ROOT" \
      --output "$junit_dir/nix-unit.xml" || status=1

    echo "==> bats"
    # GNU parallel prompts once for a citation; silence that in CI/noninteractive.
    mkdir -p "''${HOME}/.parallel"
    touch "''${HOME}/.parallel/will-cite"
    bats_jobs="$(nproc 2>/dev/null || echo 2)"
    bats_log="$junit_dir/bats.log"
    # tap + report-formatter: pretty writes to a pipe and bats-format-junit
    # exits 141 (SIGPIPE) when stdout is not a TTY (CI, act, devenv tasks).
    # Capture TAP (noisy on success); keep --print-output-on-failure in the log.
    if bats --jobs "$bats_jobs" --formatter tap --report-formatter junit --output "$junit_dir" \
      --print-output-on-failure --recursive "$DEVENV_ROOT/tests" >"$bats_log" 2>&1; then
      ok_count="$(grep -c '^ok ' "$bats_log" || true)"
      echo "==> bats: ok ($ok_count tests)"
    else
      status=1
      echo "==> bats: FAILED"
      cat "$bats_log"
    fi
    if [ ! -s "$junit_dir/report.xml" ]; then
      if bats --jobs "$bats_jobs" --formatter junit --recursive "$DEVENV_ROOT/tests" \
        >"$junit_dir/report.xml" 2>"$bats_log"; then
        :
      else
        status=1
        echo "==> bats junit fallback: FAILED"
        cat "$bats_log"
      fi
    fi
    python3 "$report" enrich-bats \
      --input "$junit_dir/report.xml" \
      --output "$junit_dir/bats.xml" \
      --root "$DEVENV_ROOT" || true
    rm -f "$junit_dir/report.xml"

    echo "==> unit junit reports in $junit_dir"
    exit "$status"
  '';

  tasks."devenv:test-devenv-unit" = {
    exec = "test-devenv-unit";
    # devenv tasks capture stdout by default; stream summaries / failures live.
    showOutput = true;
  };
}
