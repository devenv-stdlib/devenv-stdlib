_: {
  name = "devenv4monorepo";

  # cachix/devenv v2.4.0 tagged modules still ship latest-version=2.3.1; align
  # with the release CLI so require_version: true (and the enterShell notice) match.
  devenv.latestVersion = "2.4.0";

  # devenv.cachix.org is already in nix.conf (setup.sh: cachix use devenv;
  # CI: cachix-action). devenv's own pull would add it again and Nix warns.
  cachix.enable = false;

  # Codespaces / VS Code Dev Containers: writes .devcontainer/devcontainer.json
  # (committed). See https://devenv.sh/integrations/codespaces-devcontainer/
  # Upstream default updateContentCommand is `devenv test`; here that is the
  # full enterTest suite (bats / act), so create only materializes the shell.
  devcontainer.enable = true;
  devcontainer.settings.updateContentCommand = "devenv shell -- true";

  # Dogfood: opt-in CI preset ci.github_actions.pr-metrics (microsoft/PR-Metrics →
  # .github/workflows/pr-metrics.yml). Framework default is off; consumers
  # enable the same way. Rejects PRs larger than medium by default.
  # See docs/content/ci.md and presets/examples/ci-pr-metrics.nix.
  presets.ci.github_actions.pr-metrics.enable = true;

  enterShell = ''
    echo "devenv4monorepo ready: ''${USER:-unknown}@$(uname -n)"

    # Repo-local navi cheats first; home-switch sets denisidoro/cheats globally.
    if [ -d "$DEVENV_ROOT/cheats" ]; then
      export NAVI_PATH="$DEVENV_ROOT/cheats''${NAVI_PATH:+:$NAVI_PATH}"
    fi

    # Rootless Docker is the default for act. CI keeps the runner daemon.
    # shellcheck disable=SC1091
    . "$DEVENV_ROOT/home/docker-rootless.sh"
    docker_rootless_env

    # Remember merge resolutions and auto-stage them on later conflicts.
    # shellcheck disable=SC1091
    . "$DEVENV_ROOT/home/ensure-git-rerere.sh"
    ensure_git_rerere

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
    command -v treefmt
    command -v bats
    command -v parallel
    command -v shellcheck
    command -v home-manager
    command -v copier
    command -v debtmap
    git --version
    jq --version
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
    bats --jobs 1 --print-output-on-failure --recursive "$DEVENV_ROOT/tests"
  '';

  # Phase 4 cutover: Den-only HM entry (den.homes → homeConfigurations.developer).
  # Requires flakes + impure env for USER/HOME defaults.
  scripts.home-switch.exec = ''
    arch=$(uname -m)
    if [ "$arch" != x86_64 ]; then
      echo "Unsupported architecture $arch: only x86_64 Linux is supported (Den declares homes.x86_64-linux.developer)" >&2
      exit 1
    fi
    # shellcheck disable=SC1091
    . "$DEVENV_ROOT/home/nix-path.sh"
    ensure_nixpkgs_on_nix_path
    # SecretSpec first (dotenv, keyring, …). .env only if export is unavailable.
    # shellcheck disable=SC1091
    . "$DEVENV_ROOT/home/load-secrets.sh"
    home_load_secrets "$DEVENV_ROOT"
    home-manager switch -b backup --flake "$DEVENV_ROOT#developer" --impure "$@"
  '';
}
