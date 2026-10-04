#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
# non-nix catalog add/remove (edit-catalog.sh). No network.

bats_require_minimum_version 1.5.0

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  EDIT_SH="$REPO_DIR/modules/non-nix/edit-catalog.sh"
  FIXTURE=$(mktemp -d)
  export DEVENV_ROOT="$FIXTURE"
  mkdir -p "$FIXTURE/modules/non-nix"
}

teardown() {
  rm -rf "$FIXTURE"
}

write_shipped() {
  cat >"$FIXTURE/modules/non-nix/catalog.toml" <<'EOF'
  # Header comment - leave intact.
# Sibling CLI. Docs: https://example.test/sibling
[[tool]]
name = "sibling"
kind = "cli"
scope = "user"
pin = "1.0.0"
mise = "npm:sibling"

# Target CLI. Docs: https://example.test/target
[[tool]]
name = "target"
kind = "cli"
scope = "project"
pin = "0.1.0"
mise = "ubi:owner/target"

# Trailing CLI. Docs: https://example.test/trailing
[[tool]]
name = "trailing"
kind = "cli"
scope = "user"
pin = "2.0.0"
mise = "npm:trailing"
EOF
}

@test "add-local dry-run prints block and does not write" {
  command -v python3 >/dev/null || skip "python3 not installed"
  printf '# shipped\n' >"$FIXTURE/modules/non-nix/catalog.toml"
  cat >"$FIXTURE/catalog.local.toml.example" <<'EOF'
# Repo-shared non-Nix tools.
EOF

  run bash "$EDIT_SH" add-local \
    --name example-cli --kind cli --scope project --pin 1.0.0 \
    --mise ubi:owner/example-cli \
    --docs 'Example CLI. Docs: https://example.com' \
    --dry-run
  [ "$status" -eq 0 ]
  [[ $output == *dry-run* ]]
  [[ $output == *'name = "example-cli"'* ]]
  [[ $output == *'# Example CLI. Docs: https://example.com'* ]]
  [ ! -f "$FIXTURE/modules/non-nix/catalog.local.toml" ]
}

@test "add-local creates catalog from root example and appends tool" {
  command -v python3 >/dev/null || skip "python3 not installed"
  printf '# shipped\n' >"$FIXTURE/modules/non-nix/catalog.toml"
  cat >"$FIXTURE/catalog.local.toml.example" <<'EOF'
# Repo-shared non-Nix tools for this monorepo.
EOF

  run bash "$EDIT_SH" add-local \
    --name example-cli --kind cli --scope project --pin 1.0.0 \
    --mise ubi:owner/example-cli \
    --docs 'Example CLI. Docs: https://example.com'
  [ "$status" -eq 0 ]
  [ -f "$FIXTURE/modules/non-nix/catalog.local.toml" ]
  grep -q 'Repo-shared non-Nix tools' "$FIXTURE/modules/non-nix/catalog.local.toml"
  grep -q '# Example CLI. Docs: https://example.com' "$FIXTURE/modules/non-nix/catalog.local.toml"
  grep -q 'name = "example-cli"' "$FIXTURE/modules/non-nix/catalog.local.toml"
  grep -q 'mise = "ubi:owner/example-cli"' "$FIXTURE/modules/non-nix/catalog.local.toml"
}

@test "add-local refuses shipped duplicate name" {
  command -v python3 >/dev/null || skip "python3 not installed"
  write_shipped
  cat >"$FIXTURE/modules/non-nix/catalog.local.toml" <<'EOF'
# local header
EOF

  run bash "$EDIT_SH" add-local \
    --name sibling --kind cli --scope project --pin 9.9.9 \
    --mise npm:sibling --docs 'Dup. Docs: https://example.com'
  [ "$status" -eq 1 ]
  [[ $output == *"already exists in shipped"* ]]
}

@test "remove dry-run prints docs comment + block; siblings keep comments" {
  command -v python3 >/dev/null || skip "python3 not installed"
  write_shipped
  mkdir -p "$FIXTURE/includes/update"

  before=$(cat "$FIXTURE/modules/non-nix/catalog.toml")

  run bash "$EDIT_SH" remove --name target --dry-run
  [ "$status" -eq 0 ]
  [[ $output == *dry-run* ]]
  [[ $output == *'# Target CLI. Docs: https://example.test/target'* ]]
  [[ $output == *'name = "target"'* ]]
  [[ $output != *'name = "sibling"'* ]]
  [[ $output != *'Trailing CLI'* ]]

  after=$(cat "$FIXTURE/modules/non-nix/catalog.toml")
  [ "$before" = "$after" ]
}

@test "remove deletes tool and its docs comment; leaves sibling comments" {
  command -v python3 >/dev/null || skip "python3 not installed"
  write_shipped
  mkdir -p "$FIXTURE/includes/update"

  run bash "$EDIT_SH" remove --name target
  [ "$status" -eq 0 ]
  run ! grep -q 'name = "target"' "$FIXTURE/modules/non-nix/catalog.toml"
  run ! grep -q 'Target CLI' "$FIXTURE/modules/non-nix/catalog.toml"
  grep -q 'Header comment - leave intact' "$FIXTURE/modules/non-nix/catalog.toml"
  grep -q '# Sibling CLI. Docs: https://example.test/sibling' "$FIXTURE/modules/non-nix/catalog.toml"
  grep -q 'name = "sibling"' "$FIXTURE/modules/non-nix/catalog.toml"
  grep -q '# Trailing CLI. Docs: https://example.test/trailing' "$FIXTURE/modules/non-nix/catalog.toml"
  grep -q 'name = "trailing"' "$FIXTURE/modules/non-nix/catalog.toml"
}

@test "add/remove refuse without includes/update (monorepo guard)" {
  command -v python3 >/dev/null || skip "python3 not installed"
  write_shipped

  run bash "$EDIT_SH" add \
    --name x --kind cli --scope user --pin 1 --mise npm:x --docs 'x'
  [ "$status" -eq 1 ]
  [[ $output == *"includes/update"* ]]
  [[ $output == *"add-local"* ]]

  run bash "$EDIT_SH" remove --name target
  [ "$status" -eq 1 ]
  [[ $output == *"includes/update"* ]]
  [[ $output == *"remove-local"* ]]
}

@test "add dry-run in template mode does not write" {
  command -v python3 >/dev/null || skip "python3 not installed"
  write_shipped
  mkdir -p "$FIXTURE/includes/update"
  before=$(sha256sum "$FIXTURE/modules/non-nix/catalog.toml" | awk '{print $1}')

  run bash "$EDIT_SH" add \
    --name new-cli --kind cli --scope user --pin 3.0.0 \
    --mise npm:new-cli --docs 'New. Docs: https://example.com' --dry-run
  [ "$status" -eq 0 ]
  [[ $output == *dry-run* ]]
  [[ $output == *'name = "new-cli"'* ]]
  after=$(sha256sum "$FIXTURE/modules/non-nix/catalog.toml" | awk '{print $1}')
  [ "$before" = "$after" ]
}

@test "add-local --help includes Examples" {
  run bash "$EDIT_SH" add-local --help
  [ "$status" -eq 0 ]
  [[ $output == *Examples:* ]]
  [[ $output == *--name* ]]
  [[ $output == *--docs* ]]
}

@test "add-local serializes open-vsx registry and sha256" {
  command -v python3 >/dev/null || skip "python3 not installed"
  printf '# shipped\n' >"$FIXTURE/modules/non-nix/catalog.toml"
  cat >"$FIXTURE/catalog.local.toml.example" <<'EOF'
# Repo-shared non-Nix tools.
EOF

  run bash "$EDIT_SH" add-local \
    --name demo-ext --kind vscode-extension --scope user --pin 1.0.0 \
    --publisher demo --extension demo-ext \
    --registry open-vsx \
    --sha256 0cfn8l7q8cn3d69spkf78p86d153cl3683lj38glkyi23206kwrw \
    --docs 'Demo. Docs: https://example.com/demo-ext'
  [ "$status" -eq 0 ]
  grep -q 'name = "demo-ext"' "$FIXTURE/modules/non-nix/catalog.local.toml"
  grep -q 'publisher = "demo"' "$FIXTURE/modules/non-nix/catalog.local.toml"
  grep -q 'extension = "demo-ext"' "$FIXTURE/modules/non-nix/catalog.local.toml"
  grep -q 'registry = "open-vsx"' "$FIXTURE/modules/non-nix/catalog.local.toml"
  grep -q 'sha256 = "0cfn8l7q8cn3d69spkf78p86d153cl3683lj38glkyi23206kwrw"' "$FIXTURE/modules/non-nix/catalog.local.toml"
}

@test "add-local rejects open-vsx without sha256" {
  command -v python3 >/dev/null || skip "python3 not installed"
  printf '# shipped\n' >"$FIXTURE/modules/non-nix/catalog.toml"
  cat >"$FIXTURE/catalog.local.toml.example" <<'EOF'
# Repo-shared non-Nix tools.
EOF

  run bash "$EDIT_SH" add-local \
    --name demo-ext --kind vscode-extension --scope user --pin 1.0.0 \
    --publisher demo --extension demo-ext \
    --registry open-vsx \
    --docs 'Demo. Docs: https://example.com/demo-ext'
  [ "$status" -eq 1 ]
  [[ $output == *'--sha256 is required for registry=open-vsx'* ]]
  [ ! -f "$FIXTURE/modules/non-nix/catalog.local.toml" ]
}

@test "add-local rejects unknown vscode-extension registry" {
  command -v python3 >/dev/null || skip "python3 not installed"
  printf '# shipped\n' >"$FIXTURE/modules/non-nix/catalog.toml"
  cat >"$FIXTURE/catalog.local.toml.example" <<'EOF'
# Repo-shared non-Nix tools.
EOF

  run bash "$EDIT_SH" add-local \
    --name demo-ext --kind vscode-extension --scope user --pin 1.0.0 \
    --publisher demo --extension demo-ext \
    --registry not-a-registry \
    --sha256 0cfn8l7q8cn3d69spkf78p86d153cl3683lj38glkyi23206kwrw \
    --docs 'Demo. Docs: https://example.com/demo-ext'
  [ "$status" -eq 1 ]
  [[ $output == *'--registry must be marketplace or open-vsx'* ]]
  [ ! -f "$FIXTURE/modules/non-nix/catalog.local.toml" ]
}
