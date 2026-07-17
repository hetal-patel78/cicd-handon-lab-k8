#!/bin/bash
set -euo pipefail

PR_TITLE="${1:-}"
if [[ -z "$PR_TITLE" ]]; then
  echo "No PR title provided. Skipping check."
  exit 0
fi

if echo "$PR_TITLE" | grep -qE '[A-Z]+-[0-9]+'; then
  echo "✅ Jira ticket referenced in PR title: $PR_TITLE"
else
  echo "❌ PR title must reference a Jira ticket (e.g. BILL-1234)"
  exit 1
fi