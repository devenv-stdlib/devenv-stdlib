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

    # Main suite (stdlib / aspects / cross-cutting) plus additive per-owner suites
    # under tools/**/tests/unit and presets/**/tests/unit (discover-suites.nix).
    list_owner_unit_suites() {
      # Same rules as tests/lib/discover-suites.nix (unit-tested); find stays in sync
      # when that file's walk skips `_` prefixes and only accepts tests/unit/default.nix.
      find "$DEVENV_ROOT/tools" "$DEVENV_ROOT/presets" \
        \( -name '_*' -prune \) -o \
        \( -path '*/tests/unit/default.nix' -print \) \
        | sort
    }

    suite_slug() {
      local rel="$1"
      rel="''${rel#/}"
      rel="''${rel%/tests/unit/default.nix}"
      printf '%s' "$rel" | tr '/' '-'
    }

    echo "==> nix-unit (main)"
    python3 "$report" nix-unit \
      --quiet \
      --suite "$DEVENV_ROOT/tests/unit/default.nix" \
      --unit-dir "$DEVENV_ROOT/tests/unit" \
      --root "$DEVENV_ROOT" \
      --output "$junit_dir/nix-unit.xml" || status=1

    while IFS= read -r suite; do
      [ -n "$suite" ] || continue
      rel="''${suite#"$DEVENV_ROOT"/}"
      slug="$(suite_slug "$rel")"
      echo "==> nix-unit ($rel)"
      python3 "$report" nix-unit \
        --quiet \
        --suite "$suite" \
        --unit-dir "$(dirname "$suite")" \
        --root "$DEVENV_ROOT" \
        --output "$junit_dir/nix-unit-$slug.xml" || status=1
    done < <(list_owner_unit_suites)

    echo "==> bats"
    # GNU parallel prompts once for a citation; silence that in CI/noninteractive.
    mkdir -p "''${HOME}/.parallel"
    touch "''${HOME}/.parallel/will-cite"
    # GNU parallel 20260722 (bats --jobs >1 backend) sanitises $XDG_CACHE_HOME and, on
    # its first run on a machine (no ~/.parallel/tmp yet: every CI runner), exports
    # it as "" to the jobs when it was unset. Nix then resolves its cache dir to
    # the relative "nix": stray ./nix tree, `not an absolute path: "nix"` on the
    # first real tarball fetch.
    export XDG_CACHE_HOME="''${XDG_CACHE_HOME:-$HOME/.cache}"
    # Warm the Nix fetchers before bats: the first import of a tarball on a
    # machine logs `unpacking '…' into the Git cache` on stderr, and bats `run`
    # folds stderr into $output, which the Den home tests compare verbatim.
    # Pre-run the pure eval files once so that noise lands here, not in a test.
    nix --extra-experimental-features 'nix-command flakes' flake prefetch-inputs "$DEVENV_ROOT" \
      >/dev/null 2>&1 || echo "warn: nix flake prefetch-inputs failed; continuing"
    for eval_file in "$DEVENV_ROOT"/tests/home/*-eval.nix; do
      env NIX_CONFIG="experimental-features = nix-command flakes" \
        nix-instantiate --eval --strict --impure "$eval_file" >/dev/null 2>&1 \
        || echo "warn: warm-up eval of ''${eval_file##*/} failed; continuing"
    done
    # git >= 2.55 runs geometric auto-maintenance detached after `git commit`
    # (maintenance.geometric-repack.auto = 100: two loose objects under
    # objects/17 are enough). copier.bats commits a ~500-object template and
    # copier then clones it / rmtree()s its throwaway repos while that repack
    # is still deleting loose objects: `failed to copy file …: No such file`,
    # `Directory not empty: '…/.git/objects'`. Turn it off for every git the
    # tests spawn, appending to any GIT_CONFIG_* the caller already set.
    git_cfg_n="''${GIT_CONFIG_COUNT:-0}"
    export "GIT_CONFIG_KEY_$git_cfg_n=maintenance.auto" \
      "GIT_CONFIG_VALUE_$git_cfg_n=false" GIT_CONFIG_COUNT=$((git_cfg_n + 1))
    # Serial on purpose: `builtins.getFlake (toString ../..)` is a path: input
    # (Nix never upgrades a string flakeref to git+file without a baseDir), so
    # every Den eval copies the checkout into the store under the fetcher lock
    # and a concurrent loser prints `waiting for another Nix process to finish
    # fetching input …` at error level, into the `$output` those tests compare
    # verbatim. --jobs 1 costs ~30 s on 4 cores; the warm-up above keeps the
    # rest of the first-fetch noise out of the tests.
    bats_log="$junit_dir/bats.log"
    # tap + report-formatter: pretty writes to a pipe and bats-format-junit
    # exits 141 (SIGPIPE) when stdout is not a TTY (CI, act, devenv tasks).
    # Capture TAP (noisy on success); keep --print-output-on-failure in the log.
    if bats --jobs 1 --formatter tap --report-formatter junit --output "$junit_dir" \
      --print-output-on-failure --recursive "$DEVENV_ROOT/tests" >"$bats_log" 2>&1; then
      ok_count="$(grep -c '^ok ' "$bats_log" || true)"
      echo "==> bats: ok ($ok_count tests)"
    else
      status=1
      echo "==> bats: FAILED"
      cat "$bats_log"
    fi
    if [ ! -s "$junit_dir/report.xml" ]; then
      if bats --jobs 1 --formatter junit --recursive "$DEVENV_ROOT/tests" \
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
