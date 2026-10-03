#!/usr/bin/env bash
set -euo pipefail

BOOTSTRAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$BOOTSTRAP_DIR/.." && pwd)"
TFVARS_FILE="$BOOTSTRAP_DIR/terraform.tfvars"
GITHUB_TOKEN_CACHE="${GITHUB_TOKEN:-}"
GH_TOKEN_CACHE="${GH_TOKEN:-}"
export GITHUB_TOKEN=""
unset GH_TOKEN

restore_github_tokens() {
  export GITHUB_TOKEN="$GITHUB_TOKEN_CACHE"
  if [[ -n "$GH_TOKEN_CACHE" ]]; then
    export GH_TOKEN="$GH_TOKEN_CACHE"
  else
    unset GH_TOKEN
  fi
}
trap restore_github_tokens EXIT

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'Required command not found: %s\n' "$1" >&2
    exit 1
  }
}

for command in az gcloud gh terraform; do
  require_command "$command"
done

if [[ ! -f "$TFVARS_FILE" ]]; then
  printf 'Missing %s. Copy terraform.tfvars.example to terraform.tfvars and fill it in.\n' "$TFVARS_FILE" >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  gh auth login
fi

if ! az account show >/dev/null 2>&1; then
  az login --use-device-code
fi

if ! gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null | grep -q .; then
  gcloud auth login
fi

if ! gcloud auth application-default print-access-token >/dev/null 2>&1; then
  gcloud auth application-default login \
    --scopes='https://www.googleapis.com/auth/cloud-platform,https://www.googleapis.com/auth/androidpublisher'
fi

if [[ -z "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]]; then
  GCLOUD_CONFIG_DIR="$(gcloud info --format='value(config.paths.global_config_dir)')"
  export GOOGLE_APPLICATION_CREDENTIALS="$GCLOUD_CONFIG_DIR/application_default_credentials.json"
fi

if [[ ! -f "$GOOGLE_APPLICATION_CREDENTIALS" ]]; then
  printf 'Google application credentials file not found: %s\n' "$GOOGLE_APPLICATION_CREDENTIALS" >&2
  exit 1
fi

REPOSITORY_SLUG="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
export TF_VAR_github_owner="${REPOSITORY_SLUG%%/*}"
export TF_VAR_github_repository="${REPOSITORY_SLUG#*/}"
export TF_VAR_github_repository_id="$(gh api "repos/$REPOSITORY_SLUG" --jq .id)"

if ! gh api "repos/$REPOSITORY_SLUG/actions/secrets?per_page=1" >/dev/null; then
  printf 'GitHub token cannot access repository Actions secrets. Grant it Actions read/write permission (fine-grained token) or repo scope (classic token), then retry.\n' >&2
  exit 1
fi

export GITHUB_TOKEN="$(gh auth token)"
terraform -chdir="$BOOTSTRAP_DIR" init
GCP_PROJECT_ID="$(terraform -chdir="$BOOTSTRAP_DIR" console -var-file="$TFVARS_FILE" <<< 'var.gcp_project_id' | tr -d '"')"
gcloud auth application-default set-quota-project "$GCP_PROJECT_ID"
terraform -chdir="$BOOTSTRAP_DIR" apply -var-file="$TFVARS_FILE" "$@"