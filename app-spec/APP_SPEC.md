# GitHub App Specification

This document defines the contract between the GitHub App (separate repository)
and this `aicli-workflow` repository.

## App Responsibilities

### On `installation.created`

Install `dispatch-workflow-template.yml` (processed from this directory) into
the default branch of each newly installed repository:

```
Target path : .github/workflows/ai-cli-dispatch.yml
Commit msg  : "chore: add AI CLI dispatch workflow [{{APP_NAME}}]"
Author      : {{APP_NAME}} <noreply@github.com>
```

Template substitutions the App must perform before committing:

| Placeholder      | Replace with                              |
|------------------|-------------------------------------------|
| `{{APP_NAME}}`   | The app's configured display name         |
| `{{AICLI_REPO}}` | This repository's full name (`owner/repo`)|

### On `installation.deleted`

Remove `.github/workflows/ai-cli-dispatch.yml` from the user's repository.

### On PR/comment events

The App does **not** directly respond to PR or comment webhooks.
The dispatch workflow (installed in the user's repo) handles routing and calls
back into this repository's reusable workflows.

The App's GitHub App installation token (`AI_CLI_APP_TOKEN`) is refreshed and
written to the user's repository secrets before each workflow execution, or on
a scheduled basis.

## Required GitHub App Permissions

```yaml
permissions:
  pull_requests: write   # post review comments
  issues: write          # post issue/PR comments
  contents: write        # install/remove the dispatch workflow file
  actions: read          # read workflow run status (optional, for diagnostics)
  metadata: read         # required baseline
```

## Webhook Events to Subscribe

```
installation          → created, deleted
```

The dispatch workflow in the user's repo handles all other event routing
(`pull_request`, `issue_comment`, `pull_request_review_comment`) internally
via GitHub Actions. The App does not need separate subscriptions for these.

## App Name Configuration

The App display name is configured at deploy time via an environment variable:

```
APP_DISPLAY_NAME=<your app name>
```

This value is substituted into the dispatch workflow template and used as the
default for comment headers (users can override per-repo via `AI_CLI_APP_NAME`
repository variable).

## Secrets and Variables in User Repositories

The App does **not** write secrets to user repositories.

The user sets the following **once** after merging the provisioned PR:

| Name | Type | Value |
|------|------|-------|
| `AI_CLI_API_KEY` | Secret | AI provider key (e.g. Gemini) — set manually by user |
| `AI_CLI_APP_TOKEN` | Secret | Static API key for the App backend (from `API_KEY` in `.env`) |
| `AIBOT_URL` | Variable | Backend URL (e.g. `https://aibot.example.com`) |

At workflow runtime the dispatch workflow calls `POST /api/v1/token` using
`AI_CLI_APP_TOKEN` as the Bearer key and receives a fresh GitHub installation
token. The installation token is masked (`::add-mask::`) and passed to
reusable workflows as `APP_TOKEN`. It is never stored anywhere.

## Interface Contract with Reusable Workflows

The reusable workflows in this repository expect the caller's dispatch workflow
to provide:

| Input / Secret     | Source                                          | Notes                               |
|--------------------|-------------------------------------------------|-------------------------------------|
| `AI_API_KEY`       | User's `AI_CLI_API_KEY` secret                  | Set manually by the user            |
| `APP_TOKEN`        | Runtime output of `get-token` job               | Fetched from App backend each run   |
| `app_name`         | `AI_CLI_APP_NAME` variable                      | Falls back to `{{APP_NAME}}`        |
| `skill_name`       | `AI_CLI_SKILL` variable                         | Falls back to `code-review-commons` |
| `rules`            | `AI_CLI_RULES` variable                         | Falls back to `code-inspection-common`|
