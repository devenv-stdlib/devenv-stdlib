#!/usr/bin/env bats
# Phase 0 inventory gates (docs + pre-Den entrypoints).
# No Den input; does not evaluate Home Manager or devenv modules.

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  INVENTORY="$REPO_DIR/docs/den/cascade-inventory.md"
  ADR="$REPO_DIR/docs/adr/0001-den-composition-model.md"
  DEVENV_NIX="$REPO_DIR/devenv.nix"
}

@test "cascade inventory documents required hubs" {
  [ -f "$INVENTORY" ]
  grep -q 'Language fan-out' "$INVENTORY"
  grep -q 'Cursor nested cascade' "$INVENTORY"
  grep -q 'Terminal provider' "$INVENTORY"
  grep -q 'IDE sync bridge' "$INVENTORY"
  grep -q 'mise / non-nix' "$INVENTORY"
}

@test "cascade inventory maps project.nix helpers to quirks" {
  grep -q 'langOn' "$INVENTORY"
  grep -q 'languageHooks' "$INVENTORY"
  grep -q 'vscodeRecommendations' "$INVENTORY"
  grep -q 'serenaLanguageServers' "$INVENTORY"
  grep -q 'debtmapLanguages' "$INVENTORY"
}

@test "cascade inventory names existing cascade nix-unit goldens" {
  grep -q 'testLanguageHooksPythonDefaultsToPyright' "$INVENTORY"
  grep -q 'testSerenaLanguageServersJavascriptAndTypescriptOnce' "$INVENTORY"
  grep -q 'testVscodeRecommendationsPython' "$INVENTORY"
  grep -q 'testGnomeBindingF12' "$INVENTORY"
  grep -q 'testNonNixVersionAndHomepagePromote' "$INVENTORY"
}

@test "named cascade unit files still exist" {
  [ -f "$REPO_DIR/tests/unit/hooks.nix" ]
  [ -f "$REPO_DIR/tests/unit/serena.nix" ]
  [ -f "$REPO_DIR/tests/unit/vscode.nix" ]
  [ -f "$REPO_DIR/tests/unit/debtmap.nix" ]
  [ -f "$REPO_DIR/tests/unit/terminal.nix" ]
  [ -f "$REPO_DIR/tests/unit/non-nix.nix" ]
  [ -f "$REPO_DIR/tests/unit/versions.nix" ]
  [ -f "$REPO_DIR/tests/unit/workflow.nix" ]
}

@test "named cascade home bats still exist" {
  [ -f "$REPO_DIR/tests/home/cursor-llm.bats" ]
  [ -f "$REPO_DIR/tests/home/terminal-lib.bats" ]
  [ -f "$REPO_DIR/tests/home/watch-mcp-secrets.bats" ]
}

@test "ADR cites abort criteria and den-only spike" {
  [ -f "$ADR" ]
  grep -qi 'abort' "$ADR"
  grep -qi 'Spike failure' "$ADR"
  grep -qi 'Sole composition dependency' "$ADR"
  grep -qi 'zen is out of scope\|zen.*out of scope' "$ADR"
  grep -qi 'flake-aspects' "$ADR"
}

@test "home-switch still targets home.nix (pre-Den)" {
  grep -E 'home-manager switch .*-f "\$DEVENV_ROOT/home\.nix"' "$DEVENV_NIX"
}

@test "Phase 0 does not add a Den input" {
  ! grep -E 'denful/den|inputs\.den\b|github:denful/den' \
    "$REPO_DIR/devenv.yaml" "$REPO_DIR/devenv.lock" 2>/dev/null
  # npins (if present later) must not pin den in Phase 0 either
  if [ -f "$REPO_DIR/npins/sources.json" ]; then
    ! grep -qi '"den"' "$REPO_DIR/npins/sources.json"
  fi
}
