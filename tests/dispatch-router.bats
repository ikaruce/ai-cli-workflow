#!/usr/bin/env bats
# Tests for app-spec/dispatch-router.sh
#
# dispatch-router.sh reads GitHub event context (env vars) and writes routing
# decisions to GITHUB_OUTPUT format:
#   route_type=pr_event | mention | none
#   command=<text after @ai-cli>    (only when route_type=mention)
#   pr_number=<number>              (when available)
#
# Inputs (env vars — mirrors GitHub Actions context):
#   GITHUB_EVENT_NAME      pull_request | issue_comment | pull_request_review_comment
#   COMMENT_BODY           comment body (for issue_comment / pr_review_comment events)
#   PR_NUMBER              PR number (provided by calling workflow step)
#   IS_PR                  true | false (whether the issue is a PR, for issue_comment)

SCRIPT="$BATS_TEST_DIRNAME/../app-spec/dispatch-router.sh"

setup() {
  export GITHUB_OUTPUT="$BATS_TMPDIR/github_output"
  > "$GITHUB_OUTPUT"
}

get_output() {
  # Read a key from GITHUB_OUTPUT file
  grep "^$1=" "$GITHUB_OUTPUT" | cut -d= -f2-
}

run_router() {
  run bash "$SCRIPT"
}

# ── pull_request event ────────────────────────────────────────────────────────

@test "pull_request event routes to pr_event" {
  GITHUB_EVENT_NAME="pull_request" PR_NUMBER="42" run_router
  [ "$status" -eq 0 ]
  [[ "$(get_output route_type)" == "pr_event" ]]
}

@test "pull_request event sets pr_number output" {
  GITHUB_EVENT_NAME="pull_request" PR_NUMBER="99" run_router
  [ "$status" -eq 0 ]
  [[ "$(get_output pr_number)" == "99" ]]
}

# ── issue_comment event with @ai-cli ─────────────────────────────────────────

@test "issue_comment with @ai-cli mention routes to mention" {
  GITHUB_EVENT_NAME="issue_comment" \
  IS_PR="true" \
  PR_NUMBER="7" \
  COMMENT_BODY="@ai-cli please review the security aspects" \
  run_router
  [ "$status" -eq 0 ]
  [[ "$(get_output route_type)" == "mention" ]]
}

@test "issue_comment with @ai-cli extracts command text" {
  GITHUB_EVENT_NAME="issue_comment" \
  IS_PR="true" \
  PR_NUMBER="7" \
  COMMENT_BODY="@ai-cli review for potential race conditions" \
  run_router
  [ "$status" -eq 0 ]
  [[ "$(get_output command)" == "review for potential race conditions" ]]
}

@test "issue_comment with @ai-cli mid-sentence extracts everything after mention" {
  GITHUB_EVENT_NAME="issue_comment" \
  IS_PR="true" \
  PR_NUMBER="5" \
  COMMENT_BODY="Hey @ai-cli can you check the error handling?" \
  run_router
  [ "$status" -eq 0 ]
  [[ "$(get_output route_type)" == "mention" ]]
  [[ "$(get_output command)" == *"error handling"* ]]
}

@test "issue_comment on issue (not PR) routes to none" {
  GITHUB_EVENT_NAME="issue_comment" \
  IS_PR="false" \
  COMMENT_BODY="@ai-cli help" \
  run_router
  [ "$status" -eq 0 ]
  [[ "$(get_output route_type)" == "none" ]]
}

@test "issue_comment without @ai-cli routes to none" {
  GITHUB_EVENT_NAME="issue_comment" \
  IS_PR="true" \
  PR_NUMBER="3" \
  COMMENT_BODY="This looks good to me, LGTM" \
  run_router
  [ "$status" -eq 0 ]
  [[ "$(get_output route_type)" == "none" ]]
}

# ── pull_request_review_comment event ────────────────────────────────────────

@test "pull_request_review_comment with @ai-cli routes to mention" {
  GITHUB_EVENT_NAME="pull_request_review_comment" \
  PR_NUMBER="12" \
  COMMENT_BODY="@ai-cli is this approach thread-safe?" \
  run_router
  [ "$status" -eq 0 ]
  [[ "$(get_output route_type)" == "mention" ]]
  [[ "$(get_output command)" == *"thread-safe"* ]]
}

@test "pull_request_review_comment without @ai-cli routes to none" {
  GITHUB_EVENT_NAME="pull_request_review_comment" \
  PR_NUMBER="12" \
  COMMENT_BODY="nit: rename this variable" \
  run_router
  [ "$status" -eq 0 ]
  [[ "$(get_output route_type)" == "none" ]]
}

# ── Unknown event ─────────────────────────────────────────────────────────────

@test "unknown event type routes to none" {
  GITHUB_EVENT_NAME="push" run_router
  [ "$status" -eq 0 ]
  [[ "$(get_output route_type)" == "none" ]]
}
