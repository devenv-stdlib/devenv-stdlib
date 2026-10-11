#!/usr/bin/env bats
# Vendored skills (.agents/skills) match skills-lock.json and are attributed.

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SKILLS_DIR="$REPO_DIR/.agents/skills"
  LOCK="$REPO_DIR/skills-lock.json"
  command -v jq >/dev/null || skip "jq not installed"
}

@test "every skills-lock.json entry has a vendored SKILL.md" {
  while IFS= read -r name; do
    [ -f "$SKILLS_DIR/$name/SKILL.md" ] || {
      echo "missing .agents/skills/$name/SKILL.md"
      return 1
    }
  done < <(jq -r '.skills | keys[]' "$LOCK")
}

@test "every vendored skill is in skills-lock.json" {
  local dir name
  for dir in "$SKILLS_DIR"/*/; do
    name=$(basename "$dir")
    jq -e --arg n "$name" '.skills[$n]' "$LOCK" >/dev/null || {
      echo "$name is not in skills-lock.json"
      return 1
    }
  done
}

@test "every skill source is attributed in .agents/skills/README.md" {
  while IFS= read -r source; do
    grep -q "github.com/$source)" "$SKILLS_DIR/README.md" || {
      echo "$source missing from .agents/skills/README.md"
      return 1
    }
  done < <(jq -r '[.skills[].source] | unique[]' "$LOCK")
}
