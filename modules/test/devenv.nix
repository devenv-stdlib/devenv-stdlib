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
      # tap + report-formatter: pretty writes to a pipe and bats-format-junit
      # exits 141 (SIGPIPE) when stdout is not a TTY (CI, act, devenv tasks).
      if bats --jobs 1 --formatter tap --report-formatter junit --output "$junit_dir" \
        --print-output-on-failure --recursive "$DEVENV_ROOT/tests"; then
        :
      else
        status=1
      fi
      if [ ! -s "$junit_dir/report.xml" ]; then
        # Still stream progress to the log: capture for JUnit and mirror to STDOUT.
        bats --jobs 1 --formatter junit --recursive "$DEVENV_ROOT/tests" \
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
        # Explicit GitHub tokens: nested act + mise (debtmap) need a real value;
        # name-only --env lets act inject an empty/dummy secret → 401.
        # shellcheck disable=SC1091
        . "$DEVENV_ROOT/modules/test/act-github-env.sh"
        act_github_token_prepare
        act_opts="--user runner --env HOME=/home/runner --env TMPDIR=/tmp --env RUNNER_TEMP=/tmp --env RUNNER_TOOL_CACHE=/tmp/toolcache -v devenv-act-nix:/nix -v devenv-act-nix-cache:/home/runner/.cache/nix"
        if [ -n "$ACT_GITHUB_TOKEN_OPTS" ]; then
          act_opts="$act_opts $ACT_GITHUB_TOKEN_OPTS"
        fi
        # act --concurrent-jobs 1 only bounds whole jobs: every matrix cell of a job
        # still starts at once on the shared /nix volume (ENOSPC, `chown -R /nix`
        # racing another cell's install-nix, and parallel `nix eval`s contending for
        # the fetcher lock on the path: workspace). Enumerate the cells from a dry
        # run and run exactly one per act call by pinning every matrix key.
        # Matrix values come from our own generators and contain no whitespace.
        run_act_serial() {
          local workflow=$1
          local job filters
          while read -r job filters; do
            [ -n "$job" ] || continue
            echo "==> act -j $job $filters ($workflow)"
            # shellcheck disable=SC2086
            act workflow_call \
              --pull=false \
              --concurrent-jobs 1 \
              "''${ACT_GITHUB_TOKEN_ARGS[@]}" \
              --container-options "$act_opts" \
              -j "$job" $filters \
              -W "$workflow" \
              -P ubuntu-24.04=devenv-act:24.04 \
              -P ubuntu-26.04=devenv-act:24.04 || return 1
          done < <(
            act workflow_call -W "$workflow" -n --json --pull=false \
              -P ubuntu-24.04=devenv-act:24.04 \
              -P ubuntu-26.04=devenv-act:24.04 2>/dev/null \
              | jq -r 'select(.jobID != null)
                  | [.jobID, ((.matrix // {}) | to_entries | map("--matrix=\(.key):\(.value)") | join(" "))]
                  | join(" ")' \
              | sort -u
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
