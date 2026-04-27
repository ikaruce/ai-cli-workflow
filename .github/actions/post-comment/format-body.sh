#!/usr/bin/env bash
# format-body.sh — format a GitHub comment body for the AI CLI bot
#
# Inputs (environment variables):
#   APP_NAME  required — display name shown in the comment header
#   BODY      required — markdown content to include in the comment
#
# Output: formatted comment markdown on stdout

set -euo pipefail

if [[ -z "${APP_NAME:-}" ]]; then
  echo "Error: APP_NAME must not be empty" >&2
  exit 1
fi

cat <<EOF
<!-- ai-cli: ${APP_NAME} -->
**${APP_NAME}** · _AI-generated_

---

${BODY}
EOF
