#!/usr/bin/env bats
# Tests for .github/actions/post-comment/format-body.sh
#
# format-body.sh takes APP_NAME and BODY as env vars, prints the formatted
# comment to stdout. Keeps formatting logic testable without GitHub API calls.

SCRIPT="$BATS_TEST_DIRNAME/../.github/actions/post-comment/format-body.sh"

run_fmt() {
  # Pass variables via environment (mirrors how the action step uses them)
  APP_NAME="$1" BODY="$2" run bash "$SCRIPT"
}

# ── Marker ────────────────────────────────────────────────────────────────────

@test "output contains HTML marker with app name for de-duplication" {
  run_fmt "My Bot" "some review"
  [ "$status" -eq 0 ]
  [[ "$output" == *"<!-- ai-cli: My Bot -->"* ]]
}

# ── Header ────────────────────────────────────────────────────────────────────

@test "output contains bold app name in header" {
  run_fmt "CodeBot" "some review"
  [ "$status" -eq 0 ]
  [[ "$output" == *"**CodeBot**"* ]]
}

@test "app name with spaces is preserved in header" {
  run_fmt "AI Review Bot" "body"
  [ "$status" -eq 0 ]
  [[ "$output" == *"**AI Review Bot**"* ]]
}

# ── Body ──────────────────────────────────────────────────────────────────────

@test "body content appears in output" {
  run_fmt "Bot" "Here is my review comment"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Here is my review comment"* ]]
}

@test "body with markdown is preserved" {
  BODY="## Issues

- **HIGH**: Missing null check
- **LOW**: Rename variable"
  run_fmt "Bot" "$BODY"
  [ "$status" -eq 0 ]
  [[ "$output" == *"## Issues"* ]]
  [[ "$output" == *"Missing null check"* ]]
}

# ── Structure ─────────────────────────────────────────────────────────────────

@test "marker appears before header in output" {
  run_fmt "Bot" "body"
  [ "$status" -eq 0 ]
  MARKER_POS=$(echo "$output" | grep -n "ai-cli:" | head -1 | cut -d: -f1)
  HEADER_POS=$(echo "$output" | grep -n "\*\*Bot\*\*" | head -1 | cut -d: -f1)
  [ "$MARKER_POS" -lt "$HEADER_POS" ]
}

@test "exits 1 when APP_NAME is empty" {
  run_fmt "" "body"
  [ "$status" -eq 1 ]
  [[ "$output" == *"APP_NAME"* ]]
}
