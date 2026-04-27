#!/usr/bin/env bash
# dispatch-router.sh — determine workflow routing from GitHub event context
#
# Reads event context from environment variables (mirrors what GitHub Actions
# exposes after a preprocessing step in the dispatch workflow) and writes
# routing decisions to $GITHUB_OUTPUT.
#
# Inputs (environment variables):
#   GITHUB_EVENT_NAME   pull_request | issue_comment | pull_request_review_comment
#   COMMENT_BODY        body of the comment (for comment events)
#   PR_NUMBER           PR number (pre-extracted by the calling step)
#   IS_PR               true | false — whether the issue is a PR (for issue_comment)
#
# Outputs written to $GITHUB_OUTPUT:
#   route_type   pr_event | mention | none
#   command      text after @ai-cli (when route_type=mention)
#   pr_number    PR number (when available)

set -euo pipefail

GITHUB_OUTPUT="${GITHUB_OUTPUT:-/dev/stdout}"
GITHUB_EVENT_NAME="${GITHUB_EVENT_NAME:-}"
COMMENT_BODY="${COMMENT_BODY:-}"
PR_NUMBER="${PR_NUMBER:-}"
IS_PR="${IS_PR:-false}"

write_output() {
  echo "$1=$2" >> "$GITHUB_OUTPUT"
}

extract_command() {
  # Extract everything after the first @ai-cli mention (trimmed)
  echo "$1" | sed 's/.*@ai-cli[[:space:],]*//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//'
}

case "$GITHUB_EVENT_NAME" in

  pull_request)
    write_output route_type "pr_event"
    [[ -n "$PR_NUMBER" ]] && write_output pr_number "$PR_NUMBER"
    ;;

  issue_comment)
    # Only act on PR comments, not plain issue comments
    if [[ "$IS_PR" != "true" ]]; then
      write_output route_type "none"
      exit 0
    fi
    if echo "$COMMENT_BODY" | grep -q "@ai-cli"; then
      CMD="$(extract_command "$COMMENT_BODY")"
      write_output route_type "mention"
      write_output command "$CMD"
      [[ -n "$PR_NUMBER" ]] && write_output pr_number "$PR_NUMBER"
    else
      write_output route_type "none"
    fi
    ;;

  pull_request_review_comment)
    if echo "$COMMENT_BODY" | grep -q "@ai-cli"; then
      CMD="$(extract_command "$COMMENT_BODY")"
      write_output route_type "mention"
      write_output command "$CMD"
      [[ -n "$PR_NUMBER" ]] && write_output pr_number "$PR_NUMBER"
    else
      write_output route_type "none"
    fi
    ;;

  *)
    write_output route_type "none"
    ;;

esac
