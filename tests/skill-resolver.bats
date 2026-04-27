#!/usr/bin/env bats
# Tests for .github/actions/run-ai-task/resolve-skill.sh
#
# resolve-skill.sh resolves a skill name to a file path within the aicli repo,
# or writes inline skill_file_content to a temp file.
# Outputs the resolved absolute path to stdout.
#
# Inputs (env vars):
#   SKILL_NAME         — name of a skill under .skills/<name>/SKILL.md
#   SKILL_FILE_CONTENT — inline skill content (takes precedence over SKILL_NAME)
#   SKILLS_BASE_DIR    — base directory for .skills/ lookup (default: repo root)

SCRIPT="$BATS_TEST_DIRNAME/../.github/actions/run-ai-task/resolve-skill.sh"
FIXTURES="$BATS_TEST_DIRNAME/fixtures"

setup() {
  export SKILLS_BASE_DIR="$FIXTURES"
  TMPDIR_BACKUP="${TMPDIR:-/tmp}"
  export TMPDIR="$BATS_TMPDIR"
}

teardown() {
  export TMPDIR="$TMPDIR_BACKUP"
}

run_resolver() {
  run bash "$SCRIPT"
}

# ── SKILL_FILE_CONTENT (inline) ───────────────────────────────────────────────

@test "inline content is written to a temp file and its path returned" {
  SKILL_FILE_CONTENT="You are an inline skill." run_resolver
  [ "$status" -eq 0 ]
  # Output is a path to an existing file
  [[ -f "$output" ]]
  [[ "$(cat "$output")" == *"inline skill"* ]]
}

@test "inline content takes precedence over skill name" {
  SKILL_NAME="my-skill" SKILL_FILE_CONTENT="inline wins" run_resolver
  [ "$status" -eq 0 ]
  [[ -f "$output" ]]
  [[ "$(cat "$output")" == *"inline wins"* ]]
}

# ── SKILL_NAME (predefined) ───────────────────────────────────────────────────

@test "skill name resolves to the SKILL.md path" {
  SKILL_NAME="my-skill" run_resolver
  [ "$status" -eq 0 ]
  [[ "$output" == *"my-skill/SKILL.md" ]]
  [[ -f "$output" ]]
}

@test "resolved skill path contains expected skill content" {
  SKILL_NAME="my-skill" run_resolver
  [ "$status" -eq 0 ]
  [[ "$(cat "$output")" == *"test assistant"* ]]
}

@test "exits 1 when skill name does not exist" {
  SKILL_NAME="nonexistent-skill" run_resolver
  [ "$status" -eq 1 ]
  [[ "$output" == *"skill not found"* ]]
}

# ── Both empty ────────────────────────────────────────────────────────────────

@test "outputs empty string when neither skill_name nor content is given" {
  SKILL_NAME="" SKILL_FILE_CONTENT="" run_resolver
  [ "$status" -eq 0 ]
  [[ -z "$output" ]]
}
