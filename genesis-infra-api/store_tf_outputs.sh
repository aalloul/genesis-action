#!/usr/bin/env bash
set -euo pipefail

TF_OUTPUTS=$(terraform output -json)

process_variables() {
  jq -c '.variables[] | select(.tf_key != "")' "$MAPPING_FILE" | while IFS= read -r entry; do
    tf_key=$(echo "$entry" | jq -r '.tf_key')
    gh_name=$(echo "$entry" | jq -r '.gh_name')
    env_scoped=$(echo "$entry" | jq -r '.env_scoped')
    value=$(echo "$TF_OUTPUTS" | jq -r ".[\"$tf_key\"].value // empty")
    [[ -z "$value" ]] && continue
    if [[ "$env_scoped" == "true" ]]; then
      gh variable set "$gh_name" --body "$value" --repo "$REPO" --env "$ENVIRONMENT"
    else
      gh variable set "$gh_name" --body "$value" --repo "$REPO"
    fi
  done
}

process_secrets() {
  jq -c '.secrets[] | select(.tf_key != "")' "$MAPPING_FILE" | while IFS= read -r entry; do
    tf_key=$(echo "$entry" | jq -r '.tf_key')
    gh_name=$(echo "$entry" | jq -r '.gh_name')
    env_scoped=$(echo "$entry" | jq -r '.env_scoped')
    value=$(echo "$TF_OUTPUTS" | jq -r ".[\"$tf_key\"].value // empty")
    [[ -z "$value" ]] && continue
    if [[ "$env_scoped" == "true" ]]; then
      printf '%s' "$value" | gh secret set "$gh_name" --repo "$REPO" --env "$ENVIRONMENT"
    else
      printf '%s' "$value" | gh secret set "$gh_name" --repo "$REPO"
    fi
  done
}

process_variables
process_secrets
