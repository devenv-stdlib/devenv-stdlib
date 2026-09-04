#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
# ^ Each @test looks like a subshell, so every SETUP_* export below is reported
# as leaking or getting lost. Each one is deliberately scoped to its own test.
#
# Unit tests for setup.sh. Nothing here touches the real /nix, network, or sudo:
# setup.sh is sourced (its main guard keeps it inert) and the host paths it looks
# at are redirected through the SETUP_* variables.

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SETUP_SH="$REPO_DIR/setup.sh"
  STUB_DIR="$BATS_TEST_TMPDIR/stub-bin"
  mkdir -p "$STUB_DIR"
}

# Create a fake executable earlier on PATH than the real one.
stub() {
  local name=$1
  shift
  {
    printf '#!/usr/bin/env bash\n'
    printf '%s\n' "$@"
  } >"$STUB_DIR/$name"
  chmod +x "$STUB_DIR/$name"
}

# Expose a real tool inside the stub directory, for tests that replace PATH
# entirely to prove setup.sh notices a missing dependency.
link_real() {
  local name
  for name in "$@"; do
    ln -sf "$(command -v "$name")" "$STUB_DIR/$name"
  done
}

# Source setup.sh in a subshell and evaluate a snippet against its functions.
in_setup() {
  run env PATH="$STUB_DIR:$PATH" bash -c "source '$SETUP_SH' >/dev/null; $1" </dev/null
}

@test "setup.sh is executable and runs under bash" {
  [ -x "$SETUP_SH" ]
  run head -1 "$SETUP_SH"
  [ "$status" -eq 0 ]
  [[ $output == *bash* ]]
}

@test "setup.sh passes shellcheck" {
  command -v shellcheck >/dev/null || skip "shellcheck not installed"
  run shellcheck "$SETUP_SH"
  [ "$status" -eq 0 ]
}

@test "sourcing setup.sh installs nothing" {
  stub curl "touch '$BATS_TEST_TMPDIR/curl-ran'"
  stub sudo "touch '$BATS_TEST_TMPDIR/sudo-ran'"
  stub devenv "touch '$BATS_TEST_TMPDIR/devenv-ran'"

  in_setup "true"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -e "$BATS_TEST_TMPDIR/curl-ran" ]
  [ ! -e "$BATS_TEST_TMPDIR/sudo-ran" ]
  [ ! -e "$BATS_TEST_TMPDIR/devenv-ran" ]
}

# --- reporting helpers -------------------------------------------------------

@test "ok reports success in green with a checkmark" {
  in_setup 'ok "all good"'
  [ "$status" -eq 0 ]
  [[ $output == *"✓ all good"* ]]
  [[ $output == *$'\033[0;32m'* ]]
}

@test "fail reports failure in red with an X and exits non-zero" {
  in_setup 'fail "broken thing"'
  [ "$status" -eq 1 ]
  [[ $output == *"✗ broken thing"* ]]
  [[ $output == *$'\033[0;31m'* ]]
}

@test "fail writes to stderr" {
  run env PATH="$STUB_DIR:$PATH" bash -c "source '$SETUP_SH'; fail oops 2>/dev/null" </dev/null
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "step announces, runs, and confirms the command" {
  in_setup 'step "do the thing" true'
  [ "$status" -eq 0 ]
  [[ $output == *"→ do the thing"* ]]
  [[ $output == *"✓ do the thing"* ]]
}

@test "step aborts with an X when the command fails" {
  in_setup 'step "do the thing" false; echo NOT_REACHED'
  [ "$status" -eq 1 ]
  [[ $output == *"✗ do the thing"* ]]
  [[ $output != *NOT_REACHED* ]]
}

@test "step forwards command output instead of capturing it" {
  in_setup 'step "noisy" bash -c "echo to-stdout; echo to-stderr >&2"'
  [ "$status" -eq 0 ]
  [[ $output == *to-stdout* ]]
  [[ $output == *to-stderr* ]]
}

# --- version comparison ------------------------------------------------------

@test "nix_semver extracts the version from nix --version output" {
  in_setup 'nix_semver "nix (Nix) 2.35.1"'
  [ "$status" -eq 0 ]
  [ "$output" = "2.35.1" ]
}

@test "nix_semver yields nothing when there is no version" {
  in_setup 'nix_semver "command not found"'
  [ -z "$output" ]
}

@test "semver_gt accepts a strictly newer candidate" {
  in_setup 'semver_gt 2.36.0 2.35.1'
  [ "$status" -eq 0 ]
}

@test "semver_gt rejects an equal version" {
  in_setup 'semver_gt 2.35.1 2.35.1'
  [ "$status" -ne 0 ]
}

@test "semver_gt rejects an older candidate (the 2.35.1 to 2.34.8 downgrade)" {
  in_setup 'semver_gt 2.34.8 2.35.1'
  [ "$status" -ne 0 ]
}

@test "semver_gt compares numerically, not lexically" {
  in_setup 'semver_gt 2.9.0 2.35.1'
  [ "$status" -ne 0 ]
  in_setup 'semver_gt 2.35.1 2.9.0'
  [ "$status" -eq 0 ]
}

@test "semver_gt rejects missing versions" {
  in_setup 'semver_gt "" 2.35.1'
  [ "$status" -ne 0 ]
  in_setup 'semver_gt 2.35.1 ""'
  [ "$status" -ne 0 ]
}

# --- host detection ----------------------------------------------------------

@test "systemd_available is false without a systemd runtime directory" {
  export SETUP_SYSTEMD_DIR="$BATS_TEST_TMPDIR/no-systemd"
  in_setup 'systemd_available'
  [ "$status" -ne 0 ]
}

@test "systemd_available is true with a systemd runtime directory and systemctl" {
  export SETUP_SYSTEMD_DIR="$BATS_TEST_TMPDIR/systemd"
  mkdir -p "$SETUP_SYSTEMD_DIR"
  stub systemctl "exit 0"
  in_setup 'systemd_available'
  [ "$status" -eq 0 ]
}

@test "nix_installer_args skips the daemon when systemd is absent" {
  export SETUP_SYSTEMD_DIR="$BATS_TEST_TMPDIR/no-systemd"
  in_setup 'nix_installer_args | tr "\n" " "'
  [ "$status" -eq 0 ]
  [[ $output == *"install linux --no-confirm --init none"* ]]
}

@test "nix_installer_args keeps the daemon when systemd is present" {
  export SETUP_SYSTEMD_DIR="$BATS_TEST_TMPDIR/systemd"
  mkdir -p "$SETUP_SYSTEMD_DIR"
  stub systemctl "exit 0"
  in_setup 'nix_installer_args | tr "\n" " "'
  [ "$status" -eq 0 ]
  [[ $output != *"--init none"* ]]
}

@test "nix_daemon_socket requires a socket, not a regular file" {
  export SETUP_NIX_ROOT="$BATS_TEST_TMPDIR/nix"
  mkdir -p "$SETUP_NIX_ROOT/var/nix/daemon-socket"
  touch "$SETUP_NIX_ROOT/var/nix/daemon-socket/socket"
  in_setup 'nix_daemon_socket'
  [ "$status" -ne 0 ]
}

@test "running_in_docker detects the .dockerenv marker" {
  export SETUP_DOCKERENV="$BATS_TEST_TMPDIR/.dockerenv"
  export SETUP_CONTAINERENV="$BATS_TEST_TMPDIR/absent-containerenv"
  export SETUP_PROC_CGROUP="$BATS_TEST_TMPDIR/absent-cgroup"
  touch "$SETUP_DOCKERENV"
  in_setup 'running_in_docker'
  [ "$status" -eq 0 ]
}

@test "running_in_docker detects a container cgroup" {
  export SETUP_DOCKERENV="$BATS_TEST_TMPDIR/absent-dockerenv"
  export SETUP_CONTAINERENV="$BATS_TEST_TMPDIR/absent-containerenv"
  export SETUP_PROC_CGROUP="$BATS_TEST_TMPDIR/cgroup"
  echo "0::/kubepods/besteffort/pod123" >"$SETUP_PROC_CGROUP"
  in_setup 'running_in_docker'
  [ "$status" -eq 0 ]
}

@test "running_in_docker is false on a plain host" {
  export SETUP_DOCKERENV="$BATS_TEST_TMPDIR/absent-dockerenv"
  export SETUP_CONTAINERENV="$BATS_TEST_TMPDIR/absent-containerenv"
  export SETUP_PROC_CGROUP="$BATS_TEST_TMPDIR/cgroup"
  echo "0::/user.slice/user-1000.slice" >"$SETUP_PROC_CGROUP"
  in_setup 'running_in_docker'
  [ "$status" -ne 0 ]
}

# --- next-step guidance ------------------------------------------------------

@test "host guidance tells the user to enter devenv shell" {
  in_setup 'print_host_next_steps'
  [ "$status" -eq 0 ]
  [[ $output == *"devenv shell"* ]]
  [[ $output == *"$REPO_DIR"* ]]
}

@test "container guidance points at an entrypoint instead of an interactive shell" {
  in_setup 'print_docker_next_steps'
  [ "$status" -eq 0 ]
  [[ $output == *"docker-entrypoint.sh"* ]]
  [[ $output == *"ENTRYPOINT"* ]]
  [[ $output == *"Do not start day-to-day work with an interactive"* ]]
}

@test "print_next_steps chooses container guidance inside a container" {
  export SETUP_DOCKERENV="$BATS_TEST_TMPDIR/.dockerenv"
  touch "$SETUP_DOCKERENV"
  in_setup 'print_next_steps'
  [ "$status" -eq 0 ]
  [[ $output == *"docker-entrypoint.sh"* ]]
}

# --- store ownership ---------------------------------------------------------

@test "ensure_nix_store_writable leaves a writable store alone" {
  export SETUP_NIX_ROOT="$BATS_TEST_TMPDIR/nix"
  mkdir -p "$SETUP_NIX_ROOT/var/nix/db"
  stub sudo "touch '$BATS_TEST_TMPDIR/sudo-ran'; exit 0"
  in_setup 'SUDO=(sudo); ensure_nix_store_writable'
  [ "$status" -eq 0 ]
  [ ! -e "$BATS_TEST_TMPDIR/sudo-ran" ]
}

@test "ensure_nix_store_writable chowns a root-owned single-user store" {
  [ "$(id -u)" -ne 0 ] || skip "running as root, which short-circuits this path"
  export SETUP_NIX_ROOT="$BATS_TEST_TMPDIR/nix"
  mkdir -p "$SETUP_NIX_ROOT/var/nix/db"
  chmod 500 "$SETUP_NIX_ROOT/var/nix/db"
  stub sudo "printf '%s\n' \"\$*\" >'$BATS_TEST_TMPDIR/sudo-args'; exit 0"
  in_setup 'SUDO=(sudo); ensure_nix_store_writable'
  [ "$status" -eq 0 ]
  run cat "$BATS_TEST_TMPDIR/sudo-args"
  [[ $output == "chown -R $(id -u):$(id -g) $SETUP_NIX_ROOT" ]]
}

# --- sudo handling -----------------------------------------------------------

@test "ensure_sudo does nothing when already root" {
  stub sudo "touch '$BATS_TEST_TMPDIR/sudo-ran'; exit 0"
  in_setup 'SUDO=(); ensure_sudo'
  [ "$status" -eq 0 ]
  [ ! -e "$BATS_TEST_TMPDIR/sudo-ran" ]
}

@test "ensure_sudo accepts passwordless sudo without prompting" {
  stub sudo "exit 0"
  in_setup 'SUDO=(sudo); ensure_sudo'
  [ "$status" -eq 0 ]
  [[ $output == *"without a password prompt"* ]]
}

@test "ensure_sudo explains the missing TTY instead of hanging on a password" {
  stub sudo "exit 1"
  in_setup 'SUDO=(sudo); ensure_sudo'
  [ "$status" -eq 1 ]
  [[ $output == *"no terminal"* ]]
  [[ $output == *"docker run -it"* ]]
}

@test "ensure_sudo fails when sudo is missing entirely" {
  link_real bash
  run env PATH="$STUB_DIR" bash -c "source '$SETUP_SH'; SUDO=(sudo); ensure_sudo" </dev/null
  [ "$status" -eq 1 ]
  [[ $output == *"sudo is required"* ]]
}

@test "sudo_with_nix keeps the Nix profile on PATH for root commands" {
  stub sudo 'exec "$@"'
  in_setup 'SUDO=(sudo); sudo_with_nix printenv PATH'
  [ "$status" -eq 0 ]
  [[ $output == /nix/var/nix/profiles/default/bin:* ]]
}

# --- entrypoint --------------------------------------------------------------

@test "main refuses to run on a non-Linux host" {
  stub uname "echo Darwin"
  run env PATH="$STUB_DIR:$PATH" bash "$SETUP_SH" </dev/null
  [ "$status" -eq 1 ]
  [[ $output == *"supports Linux only"* ]]
}

@test "main requires curl before touching the network" {
  stub uname "echo Linux"
  stub sudo "exit 0"
  link_real bash cat
  run env PATH="$STUB_DIR" bash "$SETUP_SH" </dev/null
  [ "$status" -eq 1 ]
  [[ $output == *"curl is required"* ]]
}
