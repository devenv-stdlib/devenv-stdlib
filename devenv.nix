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
    # GNU parallel 20260722 (bats --jobs backend) sanitises $XDG_CACHE_HOME and, on
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
    bats --jobs "$(nproc 2>/dev/null || echo 2)" --print-output-on-failure --recursive "$DEVENV_ROOT/tests"
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
