_: {
  name = "devenv4monorepo";

  # cachix/devenv v2.4.0 tagged modules still ship latest-version=2.3.1; align
  # with the release CLI so require_version: true (and the enterShell notice) match.
  devenv.latestVersion = "2.4.0";

  # devenv.cachix.org is already in nix.conf (setup.sh: cachix use devenv;
  # CI: cachix-action). devenv's own pull would add it again and Nix warns.
  cachix.enable = false;

  enterShell = ''
    echo "devenv4monorepo ready: ''${USER:-unknown}@$(uname -n)"

    # Repo-local navi cheats first; home-switch sets denisidoro/cheats globally.
    if [ -d "$DEVENV_ROOT/cheats" ]; then
      export NAVI_PATH="$DEVENV_ROOT/cheats''${NAVI_PATH:+:$NAVI_PATH}"
    fi

    # Rootless Docker is the default for act and Docker MCP. CI keeps the runner daemon.
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
    # Serial bats: parallel jobs amplify the git maintenance race above and
    # (once Den lands) also race Nix path: flake fetcher locks.
    bats --jobs 1 --print-output-on-failure --recursive "$DEVENV_ROOT/tests"
  '';

  scripts.home-switch.exec = ''
    # shellcheck disable=SC1091
    . "$DEVENV_ROOT/home/nix-path.sh"
    ensure_nixpkgs_on_nix_path
    # SecretSpec first (dotenv, keyring, …). .env only if export is unavailable.
    # shellcheck disable=SC1091
    . "$DEVENV_ROOT/home/load-secrets.sh"
    home_load_secrets "$DEVENV_ROOT"
    # Legacy path kept through Phase 3 parity; Den path is home-switch-den.
    home-manager switch -b backup -f "$DEVENV_ROOT/home.nix" "$@"
  '';

  # Phase 1 spike: den.homes → homeConfigurations.developer (cursor cascade).
  # Requires flakes + impure env for USER/HOME defaults (same as legacy home.nix).
  scripts.home-switch-den.exec = ''
    # shellcheck disable=SC1091
    . "$DEVENV_ROOT/home/nix-path.sh"
    ensure_nixpkgs_on_nix_path
    # shellcheck disable=SC1091
    . "$DEVENV_ROOT/home/load-secrets.sh"
    home_load_secrets "$DEVENV_ROOT"
    home-manager switch -b backup --flake "$DEVENV_ROOT#developer" --impure "$@"
  '';
}
