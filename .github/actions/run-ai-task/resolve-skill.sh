#!/usr/bin/env bash
# resolve-skill.sh — resolve a skill to a file path
#
# Priority: SKILL_FILE_CONTENT > SKILL_NAME > (empty → no skill)
#
# Inputs (environment variables):
#   SKILL_FILE_CONTENT  inline skill markdown (highest priority)
#   SKILL_NAME          name of a predefined skill under $SKILLS_BASE_DIR/.skills/
#   SKILLS_BASE_DIR     base directory for .skills/ lookup (default: repo root)
#
# Output: absolute path to the resolved skill file on stdout, or empty string

set -euo pipefail

SKILLS_BASE_DIR="${SKILLS_BASE_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo ".")}"
SKILL_NAME="${SKILL_NAME:-}"
SKILL_FILE_CONTENT="${SKILL_FILE_CONTENT:-}"

# Inline content takes precedence
if [[ -n "$SKILL_FILE_CONTENT" ]]; then
  TMPFILE="$(mktemp "${TMPDIR:-/tmp}/aicli-skill.XXXXXX.md")"
  printf '%s' "$SKILL_FILE_CONTENT" > "$TMPFILE"
  echo "$TMPFILE"
  exit 0
fi

# Named skill lookup
if [[ -n "$SKILL_NAME" ]]; then
  SKILL_PATH="${SKILLS_BASE_DIR}/.skills/${SKILL_NAME}/SKILL.md"
  if [[ ! -f "$SKILL_PATH" ]]; then
    echo "Error: skill not found: '$SKILL_NAME' (expected at ${SKILL_PATH})" >&2
    exit 1
  fi
  echo "$SKILL_PATH"
  exit 0
fi

# Neither provided — output empty (no skill)
echo ""
