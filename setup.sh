#!/usr/bin/env bash
# Bootstrap or update Nix, devenv, Cachix, and Home Manager, then materialize
# this repo's development environment and user-global terminal/Cursor/Starship config.
# Cache configuration is done as root; this script does not add your user to
# Nix trusted-users.
#
# Sourcing this file defines the functions without running the installer, which
# is what tests/setup/setup.bats relies on.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Paths the tests override to exercise this script without touching the host.
: "${SETUP_NIX_ROOT:=/nix}"
: "${SETUP_NIX_INSTALLER_URL:=https://artifacts.nixos.org/nix-installer}"
: "${SETUP_SYSTEMD_DIR:=/run/systemd/system}"
: "${SETUP_DOCKERENV:=/.dockerenv}"
: "${SETUP_CONTAINERENV:=/run/.containerenv}"
: "${SETUP_PROC_CGROUP:=/proc/1/cgroup}"
# Phase 4: Den flake entry (homeConfigurations.developer). Override for tests.
: "${SETUP_HOME_FLAKE:=$REPO_ROOT#developer}"

NIX_PROFILE_DIR="${SETUP_NIX_ROOT}/var/nix/profiles/default"
NIX_DAEMON_PROFILE="${NIX_PROFILE_DIR}/etc/profile.d/nix-daemon.sh"
NIX_PROFILE_SCRIPT="${NIX_PROFILE_DIR}/etc/profile.d/nix.sh"
NIX_PROFILE_BIN="${NIX_PROFILE_DIR}/bin"
NIX_DAEMON_SOCKET="${SETUP_NIX_ROOT}/var/nix/daemon-socket/socket"
NIX_STORE_DB_DIR="${SETUP_NIX_ROOT}/var/nix/db"
NIX_FEATURES=(--extra-experimental-features 'nix-command flakes')
GREEN=$'\033[0;32m'
RED=$'\033[0;31m'
RESET=$'\033[0m'
SUDO=()

ok() {
  printf '%s✓ %s%s\n' "$GREEN" "$*" "$RESET"
}

fail() {
  printf '%s✗ %s%s\n' "$RED" "$*" "$RESET" >&2
  exit 1
}

# Named `step` rather than `run` so tests can source this file without
# shadowing bats' own `run` helper.
step() {
  local description=$1
  shift
  printf '→ %s\n' "$description"
  if "$@"; then
    ok "$description"
  else
    fail "$description"
  fi
}

# sudo drops PATH; keep Nix tools (nix-env, nix) visible to root commands.
sudo_with_nix() {
  "${SUDO[@]}" env PATH="${NIX_PROFILE_BIN}:${HOME:-}/.nix-profile/bin:${PATH}" "$@"
}

load_nix() {
  local profile
  for profile in "$NIX_DAEMON_PROFILE" "$NIX_PROFILE_SCRIPT" "${HOME:-}/.nix-profile/etc/profile.d/nix.sh"; do
    if [[ -f $profile ]]; then
      # shellcheck disable=SC1090
      . "$profile"
    fi
  done
  if [[ -d ${HOME:-}/.nix-profile/bin ]]; then
    PATH="$HOME/.nix-profile/bin:$PATH"
    export PATH
  fi
}

systemd_available() {
  [[ -d $SETUP_SYSTEMD_DIR ]] && command -v systemctl >/dev/null 2>&1
}

nix_daemon_socket() {
  [[ -S $NIX_DAEMON_SOCKET ]]
}

running_in_docker() {
  [[ -f $SETUP_DOCKERENV ]] || [[ -f $SETUP_CONTAINERENV ]] \
    || grep -qaE '(docker|containerd|kubepods)' "$SETUP_PROC_CGROUP" 2>/dev/null
}

# Without systemd the installer creates a root-only store, so record that the
# daemon is skipped and the store has to be owned by the invoking user.
nix_installer_args() {
  local -a args=(install linux --no-confirm)
  if ! systemd_available; then
    args+=(--init none)
  fi
  printf '%s\n' "${args[@]}"
}

install_nix() {
  local -a installer_args=()
  mapfile -t installer_args < <(nix_installer_args)
  if ! systemd_available; then
    printf 'No systemd detected; installing Nix without a daemon (--init none)\n'
  fi
  curl -fL "$SETUP_NIX_INSTALLER_URL" | sh -s -- "${installer_args[@]}"
}

# --init none installs a root-only store. Non-root profile commands then fail
# with "opening lock file ... Permission denied". Own the store as the user in
# that case only; never chown a multi-user daemon install.
ensure_nix_store_writable() {
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    return 0
  fi
  if nix_daemon_socket; then
    return 0
  fi
  if [[ -w $NIX_STORE_DB_DIR ]]; then
    ok "Nix store is writable for ${USER:-this user}"
    return 0
  fi
  [[ -d $SETUP_NIX_ROOT ]] || fail "Nix is installed but $SETUP_NIX_ROOT is missing"
  step "make the Nix store writable for ${USER:-this user} (single-user install, no daemon)" \
    "${SUDO[@]}" chown -R "$(id -u):$(id -g)" "$SETUP_NIX_ROOT"
}

nix_cmd() {
  load_nix
  command -v nix >/dev/null 2>&1 || return 1
  nix "${NIX_FEATURES[@]}" "$@"
}

have_nix() {
  load_nix
  command -v nix >/dev/null 2>&1
}

have_flakes() {
  load_nix
  command -v nix >/dev/null 2>&1 || return 1
  nix show-config 2>/dev/null | grep -E '^experimental-features =' | grep -qw flakes
}

profile_has() {
  local name=$1
  nix_cmd profile list 2>/dev/null | grep -E "^Name:[[:space:]]+" | grep -qw "$name"
}

nix_semver() {
  local text=$1
  grep -oE '[0-9]+\.[0-9]+\.[0-9]+' <<<"$text" | head -1
}

current_nix_semver() {
  load_nix
  nix_semver "$(nix --version 2>/dev/null)"
}

nixpkgs_nix_semver() {
  nix_semver "$(nix_cmd shell nixpkgs#nix --command nix --version 2>/dev/null)"
}

semver_gt() {
  local candidate=$1 current=$2 higher
  [[ -n $candidate && -n $current ]] || return 1
  higher=$(printf '%s\n%s\n' "$candidate" "$current" | sort -V | tail -n1)
  [[ $higher == "$candidate" && $candidate != "$current" ]]
}

# `nix upgrade-nix` installs whatever nixpkgs pins as stable, which can be older
# than an installer-provided Nix. Only upgrade when nixpkgs is actually newer.
ensure_nix() {
  local current candidate
  if ! have_nix; then
    step "download and install Nix" install_nix
    load_nix
    have_nix || fail "Nix was installed but is not on PATH; open a new shell and re-run this script"
    return
  fi

  current=$(current_nix_semver)
  [[ -n $current ]] || fail "could not determine the installed Nix version"

  printf '→ check nixpkgs for a newer Nix than %s\n' "$current"
  candidate=$(nixpkgs_nix_semver || true)
  if [[ -z $candidate ]]; then
    fail "could not query the Nix version from nixpkgs"
  fi

  if semver_gt "$candidate" "$current"; then
    step "upgrade Nix from $current to $candidate" \
      sudo_with_nix nix "${NIX_FEATURES[@]}" upgrade-nix
  else
    ok "Nix $current is already newer than or equal to nixpkgs ($candidate); skipping upgrade"
  fi
}

ensure_flakes() {
  if have_flakes; then
    ok "Nix flakes already enabled"
    return 0
  fi

  printf '→ enable Nix flakes in /etc/nix/nix.custom.conf\n'
  if "${SUDO[@]}" tee -a /etc/nix/nix.custom.conf >/dev/null <<'EOF'

extra-experimental-features = flakes
EOF
  then
    if systemd_available; then
      "${SUDO[@]}" systemctl restart nix-daemon
    fi
    ok "enabled Nix flakes"
  else
    fail "failed to enable Nix flakes"
  fi
}

ensure_profile_pkg() {
  local name=$1
  if command -v "$name" >/dev/null 2>&1 || profile_has "$name"; then
    step "upgrade $name to the latest nixpkgs version" \
      nix_cmd profile upgrade "$name"
  else
    step "install $name into the user Nix profile" \
      nix_cmd profile add "nixpkgs#$name"
  fi
  load_nix
  command -v "$name" >/dev/null 2>&1 || fail "$name is not on PATH after install"
}

# Install devenv from the locked modules rev so the CLI matches require_version.
ensure_devenv() {
  local lock=$REPO_ROOT/devenv.lock
  local rev flakeref
  [[ -f $lock ]] || fail "devenv.lock not found at $lock"
  rev=$(jq -r '.nodes.devenv.locked.rev // empty' "$lock")
  [[ -n $rev && $rev != null ]] || fail "devenv.lock has no nodes.devenv.locked.rev"
  flakeref="github:cachix/devenv/${rev}"
  if command -v devenv >/dev/null 2>&1 || profile_has devenv; then
    step "replace profile devenv with locked ${rev:0:12}" \
      nix_cmd profile remove devenv || true
  fi
  step "install devenv from locked rev ${rev:0:12}" \
    nix_cmd profile add "$flakeref"
  load_nix
  command -v devenv >/dev/null 2>&1 || fail "devenv is not on PATH after install"
}

# ensure_nixpkgs_on_nix_path: shared with home-switch and test-devenv.
# shellcheck disable=SC1091
. "$REPO_ROOT/home/nix-path.sh"

apply_home_manager() {
  command -v home-manager >/dev/null 2>&1 || fail "home-manager is not on PATH"
  local flake_uri=$SETUP_HOME_FLAKE
  local flake_dir=${flake_uri%%#*}
  [[ -d $flake_dir ]] || fail "Home Manager flake directory not found: $flake_dir"
  [[ -f $flake_dir/flake.nix ]] || fail "Home Manager flake.nix not found under: $flake_dir"
  ensure_nixpkgs_on_nix_path
  step "apply Home Manager configuration via Den flake (terminal, Cursor, Starship)" \
    home-manager switch -b backup --flake "$flake_uri" --impure
}

ensure_sudo() {
  if [[ ${#SUDO[@]} -eq 0 ]]; then
    return 0
  fi
  command -v sudo >/dev/null 2>&1 || fail "sudo is required to configure Nix as root"
  if "${SUDO[@]}" -n true 2>/dev/null; then
    ok "sudo is available without a password prompt"
    return 0
  fi
  # `sudo -v` always wants a terminal, so only prompt when we actually have one.
  if [[ -t 0 ]]; then
    printf '→ verifying sudo credentials\n'
    if "${SUDO[@]}" -v; then
      ok "sudo credentials available"
    else
      fail "sudo authentication failed"
    fi
    return 0
  fi
  fail "sudo needs a password but this session has no terminal. Re-run with a TTY (for example: docker run -it) or allow passwordless sudo."
}

print_notice() {
  cat <<'EOF'
This script installs or updates Nix, devenv, Cachix, and Home Manager,
configures the devenv binary cache, applies this repository's Home Manager
configuration (terminal, Cursor, Starship), and builds the devenv shell.

This stack expects rootless Docker on the host (local act, Docker MCP).
It does not install Docker. See
https://docs.docker.com/engine/security/rootless/

Elevated privileges (sudo) are required for:
  - installing or upgrading the Nix daemon
  - enabling the flakes experimental feature in /etc/nix (if missing)
  - configuring the devenv Cachix cache with `cachix use devenv`
  - installing AppArmor profiles so Cursor Agent terminal sandbox works on
    Ubuntu (kernel.apparmor_restrict_unprivileged_userns=1)
  - on systems without systemd: making /nix writable for your user after a
    single-user (--init none) install

Your user will not be added to Nix trusted-users. Cache and daemon
configuration is performed as root.
EOF
  printf '\n'
}

print_host_next_steps() {
  printf 'Enter it with: cd %s && devenv shell\n' "$REPO_ROOT"
  print_rootless_docker_hint
}

print_rootless_docker_hint() {
  local runtime sock
  if running_in_docker; then
    return 0
  fi
  runtime=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
  sock=$runtime/docker.sock
  if [[ -S $sock ]]; then
    ok "rootless Docker socket $sock"
    return 0
  fi
  cat <<EOF
This template defaults to rootless Docker (act, Docker MCP).
The user socket is missing ($sock). Install Engine extras, then:

  dockerd-rootless-setuptool.sh install
  systemctl --user enable --now docker
  loginctl enable-linger "\$USER"

Docs: https://docs.docker.com/engine/security/rootless/
Override with DOCKER_HOST=unix:///var/run/docker.sock for a rootful daemon.
EOF
}

print_docker_next_steps() {
  cat <<'EOF'
This session is a container. Do not start day-to-day work with an interactive
`devenv shell` in the terminal. Add a Docker entrypoint that loads Nix and
execs devenv so every container start gets the same toolchain.

Example docker-entrypoint.sh (chmod +x, COPY into the image):

#!/usr/bin/env bash
set -euo pipefail
if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
elif [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix.sh ]]; then
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
fi
export PATH="${HOME}/.nix-profile/bin:${PATH}"
cd /path/to/your/project
if [[ $# -eq 0 ]]; then
  exec devenv shell
fi
exec devenv shell -- "$@"

Dockerfile:

  COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
  ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
  CMD ["bash"]

Replace /path/to/your/project with the directory that contains devenv.nix
(the path you COPY or bind-mount into the image).
EOF
}

print_next_steps() {
  if running_in_docker; then
    print_docker_next_steps
  else
    print_host_next_steps
  fi
}

main() {
  local cachix_bin

  [[ $(uname -s) == Linux ]] || fail "This setup script supports Linux only"
  [[ $(uname -m) == x86_64 ]] || fail "Unsupported architecture $(uname -m): only x86_64 Linux is supported (Den declares homes.x86_64-linux.developer)"

  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    SUDO=()
  else
    SUDO=(sudo)
  fi

  print_notice
  ensure_sudo

  command -v curl >/dev/null 2>&1 || fail "curl is required to download the Nix installer"

  ensure_nix
  ensure_nix_store_writable
  load_nix
  ensure_flakes
  load_nix

  ensure_devenv
  ensure_profile_pkg cachix
  ensure_profile_pkg home-manager

  cachix_bin="$(command -v cachix)"
  [[ -n $cachix_bin ]] || fail "cachix binary not found"

  step "configure the devenv Cachix binary cache as root" \
    sudo_with_nix "$cachix_bin" use devenv

  if [[ -x $REPO_ROOT/includes/cursor-agent-sandbox/install.sh ]]; then
    step "install Cursor Agent terminal sandbox AppArmor profiles" \
      "${SUDO[@]}" "$REPO_ROOT/includes/cursor-agent-sandbox/install.sh"
  fi

  cd "$REPO_ROOT" || fail "cannot enter $REPO_ROOT"

  # shellcheck disable=SC1091
  . "$REPO_ROOT/home/ensure-git-rerere.sh"
  ensure_git_rerere

  printf '→ trust this directory for devenv auto-activation\n'
  if devenv allow; then
    ok "trusted this directory for devenv auto-activation"
  else
    printf '%s✗ trust this directory for devenv auto-activation (continuing)%s\n' "$RED" "$RESET" >&2
  fi

  apply_home_manager

  step "build this repository's development environment" \
    devenv shell -- true

  ok "development environment is ready"
  print_next_steps
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
