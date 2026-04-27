#!/usr/bin/env bash
# ai-cli — AI CLI abstraction wrapper
#
# Delegates to the configured AI tool (default: gemini).
# Swap the underlying tool by setting AI_CLI_TOOL without changing callers.
#
# Supported tools:
#   gemini  — @google/gemini-cli (explicit support with API key mapping)
#   <other> — any binary in PATH is invoked generically with -p / --model
#
# NOTE: This file is the canonical source.
#       .github/actions/setup-ai-cli/ai-cli.sh must be kept identical.
#
# Usage: ai-cli [OPTIONS]
#   --skill <path>        Skill file (SKILL.md frontmatter + body)
#   --rules <path>        Rule file (repeatable)
#   --prompt <text>       Free-form prompt text
#   --context <path>      Context file to append (diff, code, etc.)
#   --output-format <fmt> markdown | json  (default: markdown)
#   --model <id>          Model ID override
#
# Environment:
#   AI_CLI_TOOL      Binary to invoke            (default: gemini)
#   AI_CLI_MODEL     Default model ID            (optional)
#   AI_CLI_API_KEY   API key — mapped to tool-specific var for known tools

set -euo pipefail

# ── Defaults ─────────────────────────────────────────────────────────────────

AI_TOOL="${AI_CLI_TOOL:-gemini}"
MODEL="${AI_CLI_MODEL:-}"
SKILL_PATH=""
RULES_PATHS=()
PROMPT=""
CONTEXT_FILE=""
OUTPUT_FORMAT="markdown"

# ── Argument parsing ──────────────────────────────────────────────────────────

usage() {
  cat >&2 <<'EOF'
Usage: ai-cli [OPTIONS]

Options:
  --skill <path>        Skill file (SKILL.md format)
  --rules <path>        Rule file (repeatable for multiple rules)
  --prompt <text>       Free-form prompt text
  --context <path>      Context file (diff, code, etc.)
  --output-format <fmt> markdown | json  (default: markdown)
  --model <id>          Model ID override

Environment:
  AI_CLI_TOOL      AI binary to invoke (default: gemini)
  AI_CLI_MODEL     Default model ID
  AI_CLI_API_KEY   API key (auto-mapped to tool-specific env var for known tools)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill)          SKILL_PATH="$2";         shift 2 ;;
    --rules)          RULES_PATHS+=("$2");      shift 2 ;;
    --prompt)         PROMPT="$2";             shift 2 ;;
    --context)        CONTEXT_FILE="$2";       shift 2 ;;
    --output-format)  OUTPUT_FORMAT="$2";      shift 2 ;;
    --model)          MODEL="$2";              shift 2 ;;
    --help|-h)        usage; exit 0 ;;
    *) echo "Error: unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

# ── Validation ────────────────────────────────────────────────────────────────

if [[ -z "$SKILL_PATH" && ${#RULES_PATHS[@]} -eq 0 && -z "$PROMPT" ]]; then
  echo "Error: provide at least one of --skill, --rules, or --prompt" >&2
  exit 1
fi

if [[ -n "$SKILL_PATH" && ! -f "$SKILL_PATH" ]]; then
  echo "Error: skill file not found: $SKILL_PATH" >&2
  exit 1
fi

if [[ -n "$CONTEXT_FILE" && ! -f "$CONTEXT_FILE" ]]; then
  echo "Error: context file not found: $CONTEXT_FILE" >&2
  exit 1
fi

case "$OUTPUT_FORMAT" in
  markdown|json) ;;
  *) echo "Error: unknown output format: $OUTPUT_FORMAT (use markdown or json)" >&2; exit 1 ;;
esac

# ── Build prompt ──────────────────────────────────────────────────────────────

PARTS=()

# 1. Skill (persona + instructions) — strip YAML frontmatter if present
if [[ -n "$SKILL_PATH" ]]; then
  # awk: skip lines between the first and second '---' fence
  SKILL_BODY="$(awk 'BEGIN{fm=0} /^---/{fm++;next} fm!=1{print}' "$SKILL_PATH")"
  # If no frontmatter, the whole file survives; if body is empty, fall back
  [[ -z "$SKILL_BODY" ]] && SKILL_BODY="$(cat "$SKILL_PATH")"
  PARTS+=("$SKILL_BODY")
fi

# 2. Rules — concatenated in declared order
for RULE_PATH in "${RULES_PATHS[@]+"${RULES_PATHS[@]}"}"; do
  if [[ -f "$RULE_PATH" ]]; then
    PARTS+=("$(cat "$RULE_PATH")")
  else
    echo "Warning: rule file not found (skipping): $RULE_PATH" >&2
  fi
done

# 3. Direct prompt
[[ -n "$PROMPT" ]] && PARTS+=("$PROMPT")

# Assemble with section separators
FULL_PROMPT=""
for PART in "${PARTS[@]+"${PARTS[@]}"}"; do
  FULL_PROMPT+="${PART}"$'\n\n---\n\n'
done

# 4. Context block
if [[ -n "$CONTEXT_FILE" ]]; then
  FULL_PROMPT+=$'## Input\n\n'"$(cat "$CONTEXT_FILE")"$'\n\n'
fi

# 5. Output format instruction
case "$OUTPUT_FORMAT" in
  markdown) FULL_PROMPT+="Output your response in Markdown format." ;;
  json)     FULL_PROMPT+="Output valid JSON only. No markdown code fences or surrounding text." ;;
esac

# ── Write prompt to temp file (avoids ARG_MAX limits on large diffs) ─────────

PROMPT_FILE="$(mktemp /tmp/ai-cli-prompt.XXXXXX)"
trap 'rm -f "$PROMPT_FILE"' EXIT
printf '%s' "$FULL_PROMPT" > "$PROMPT_FILE"

# ── Invoke the AI tool ────────────────────────────────────────────────────────
# Known tools: receive explicit API key mapping and tool-specific invocation.
# Other binaries: invoked generically with -p <prompt> [--model <model>].
# Binary not in PATH: hard error.

# Map AI_CLI_API_KEY to tool-specific env vars for known tools
case "$AI_TOOL" in
  gemini)
    [[ -n "${AI_CLI_API_KEY:-}" ]] && export GEMINI_API_KEY="${AI_CLI_API_KEY}"
    ;;
esac

case "$AI_TOOL" in
  gemini)
    TOOL_ARGS=(-p "$(cat "$PROMPT_FILE")" --yolo)
    [[ -n "$MODEL" ]] && TOOL_ARGS+=(--model "$MODEL")
    gemini "${TOOL_ARGS[@]}"
    ;;
  *)
    # Generic passthrough — supports any binary that accepts -p / --model
    if ! command -v "$AI_TOOL" &>/dev/null; then
      echo "Error: unsupported AI tool: '$AI_TOOL' (not found in PATH)" >&2
      exit 1
    fi
    TOOL_ARGS=(-p "$(cat "$PROMPT_FILE")")
    [[ -n "$MODEL" ]] && TOOL_ARGS+=(--model "$MODEL")
    "$AI_TOOL" "${TOOL_ARGS[@]}"
    ;;
esac
