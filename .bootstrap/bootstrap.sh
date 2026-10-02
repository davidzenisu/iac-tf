#!/usr/bin/env bash
set -euo pipefail

BOOTSTRAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$BOOTSTRAP_DIR/.." && pwd)"
TFVARS_FILE="$BOOTSTRAP_DIR/terraform.tfvars"

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

REPOSITORY_SLUG="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
export TF_VAR_github_owner="${REPOSITORY_SLUG%%/*}"
export TF_VAR_github_repository="${REPOSITORY_SLUG#*/}"
export TF_VAR_github_repository_id="$(gh api "repos/$REPOSITORY_SLUG" --jq .id)"
export GITHUB_TOKEN="$(gh auth token)"

terraform -chdir="$BOOTSTRAP_DIR" init
terraform -chdir="$BOOTSTRAP_DIR" apply -var-file="$TFVARS_FILE" "$@"