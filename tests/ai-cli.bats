#!/usr/bin/env bats
# Tests for scripts/ai-cli.sh
#
# Uses a fake AI tool (tests/helpers/fake-ai.sh) to avoid real API calls.
# The fake tool echoes its arguments so we can assert prompt construction.

SCRIPT="$BATS_TEST_DIRNAME/../scripts/ai-cli.sh"
FIXTURES="$BATS_TEST_DIRNAME/fixtures"

# ── Helpers ───────────────────────────────────────────────────────────────────

setup() {
  # Provide a fake AI tool that captures the prompt it receives
  export PATH="$BATS_TEST_DIRNAME/helpers:$PATH"
  export AI_CLI_TOOL="fake-ai"
  export AI_CLI_API_KEY="test-key"
  unset AI_CLI_MODEL
}

# Run ai-cli.sh as a subprocess (requires executable bit)
run_cli() {
  run bash "$SCRIPT" "$@"
}

# ── Input validation ──────────────────────────────────────────────────────────

@test "exits 1 and prints error when no input is given" {
  run_cli
  [ "$status" -eq 1 ]
  [[ "$output" == *"provide at least one of --skill, --rules, or --prompt"* ]]
}

@test "exits 1 when --skill file does not exist" {
  run_cli --skill /nonexistent/SKILL.md
  [ "$status" -eq 1 ]
  [[ "$output" == *"skill file not found"* ]]
}

@test "exits 1 when --context file does not exist" {
  run_cli --prompt "hello" --context /nonexistent/context.md
  [ "$status" -eq 1 ]
  [[ "$output" == *"context file not found"* ]]
}

@test "exits 1 for unknown --output-format" {
  run_cli --prompt "hello" --output-format xml
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown output format"* ]]
}

@test "exits 1 for unknown --ai-tool via env" {
  AI_CLI_TOOL="no-such-tool" run_cli --prompt "hello"
  [ "$status" -eq 1 ]
  [[ "$output" == *"unsupported AI tool"* ]]
}

@test "exits 0 and shows usage for --help" {
  run_cli --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: ai-cli"* ]]
}

@test "exits 1 for unknown option" {
  run_cli --unknown-flag value
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown option"* ]]
}

# ── Prompt construction: skill ────────────────────────────────────────────────

@test "skill body is included in prompt (frontmatter stripped)" {
  run_cli --skill "$FIXTURES/.skills/my-skill/SKILL.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"You are a test assistant"* ]]
  [[ "$output" != *"name: my-skill"* ]]
}

@test "skill without frontmatter is included as-is" {
  run_cli --skill "$FIXTURES/.skills/no-frontmatter/SKILL.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"You are a no-frontmatter assistant"* ]]
}

# ── Prompt construction: rules ────────────────────────────────────────────────

@test "single rule file is included in prompt" {
  run_cli --rules "$FIXTURES/rules/rule-a.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Always be concise"* ]]
}

@test "multiple rule files are all included" {
  run_cli \
    --rules "$FIXTURES/rules/rule-a.md" \
    --rules "$FIXTURES/rules/rule-b.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Always be concise"* ]]
  [[ "$output" == *"Always be accurate"* ]]
}

@test "missing rule file emits warning and continues" {
  run_cli \
    --rules "$FIXTURES/rules/rule-a.md" \
    --rules "/nonexistent/rule.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Always be concise"* ]]
  [[ "$output" == *"Warning: rule file not found"* ]]
}

# ── Prompt construction: direct prompt ───────────────────────────────────────

@test "--prompt text is included in prompt" {
  run_cli --prompt "review this change"
  [ "$status" -eq 0 ]
  [[ "$output" == *"review this change"* ]]
}

# ── Prompt construction: context ─────────────────────────────────────────────

@test "--context content appears under '## Input' section" {
  run_cli --prompt "review" --context "$FIXTURES/context.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"## Input"* ]]
  [[ "$output" == *"def hello"* ]]
}

# ── Prompt construction: combined ────────────────────────────────────────────

@test "skill + rules + prompt + context all appear in prompt" {
  run_cli \
    --skill "$FIXTURES/.skills/my-skill/SKILL.md" \
    --rules "$FIXTURES/rules/rule-a.md" \
    --prompt "review this" \
    --context "$FIXTURES/context.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"You are a test assistant"* ]]
  [[ "$output" == *"Always be concise"* ]]
  [[ "$output" == *"review this"* ]]
  [[ "$output" == *"## Input"* ]]
  [[ "$output" == *"def hello"* ]]
}

# ── Output format ─────────────────────────────────────────────────────────────

@test "default output format instructs markdown" {
  run_cli --prompt "hello"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Markdown format"* ]]
}

@test "--output-format json instructs JSON output" {
  run_cli --prompt "hello" --output-format json
  [ "$status" -eq 0 ]
  [[ "$output" == *"valid JSON only"* ]]
}

# ── API key mapping ───────────────────────────────────────────────────────────

@test "AI_CLI_API_KEY is exported as FAKE_AI_API_KEY for fake-ai tool" {
  AI_CLI_TOOL="fake-ai" AI_CLI_API_KEY="my-secret" run_cli --prompt "hello"
  [ "$status" -eq 0 ]
  # fake-ai echoes env vars — see tests/helpers/fake-ai.sh
  [[ "$output" == *"FAKE_AI_API_KEY=my-secret"* ]]
}

# ── Model passthrough ─────────────────────────────────────────────────────────

@test "--model flag is passed to the underlying tool" {
  run_cli --prompt "hello" --model "test-model-v1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"MODEL=test-model-v1"* ]]
}

@test "AI_CLI_MODEL env var is used as default model" {
  AI_CLI_MODEL="env-model-v2" run_cli --prompt "hello"
  [ "$status" -eq 0 ]
  [[ "$output" == *"MODEL=env-model-v2"* ]]
}

@test "--model flag overrides AI_CLI_MODEL env var" {
  AI_CLI_MODEL="env-model" run_cli --prompt "hello" --model "flag-model"
  [ "$status" -eq 0 ]
  [[ "$output" == *"MODEL=flag-model"* ]]
}
