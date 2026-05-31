#!/usr/bin/env bash
set -euo pipefail

red='\033[0;31m'
green='\033[0;32m'
nc='\033[0m' # No Color

require_gh_login() {
  if gh auth status >/dev/null 2>&1; then
    echo "Already logged into GitHub CLI."
  else
    echo "GitHub CLI login required."
    gh auth login
  fi
}

require_gcloud_login() {
  if gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | grep -q .; then
    echo "Already logged into Google Cloud CLI."
  else
    echo "Google Cloud CLI login required."
    gcloud auth login
  fi
}

require_gh_login
require_gcloud_login

read -p "Enter your GCP project display name. If the project doesn't exist, it will be created: " GC_PROJECT_DISPLAY_NAME
read -p "Enter your GCP service account name (example: github-actions-sa): " GCP_SERVICE_ACCOUNT_NAME

WI_POOL_NAME="gh-oidc"


PROJECT_ID=$(gcloud projects list --filter="name:'$GC_PROJECT_DISPLAY_NAME'" --format="value(projectId)")

if [[ -z "$PROJECT_ID" ]]; then
  echo "No project found with the display name: $GC_PROJECT_DISPLAY_NAME. Creating..."
  # create project
  random_suffix=$(tr -dc a-z0-9 </dev/urandom | head -c 6; echo)
  PROJECT_ID="${GC_PROJECT_DISPLAY_NAME}-${random_suffix}"
  echo "Creating project $GC_PROJECT_DISPLAY_NAME (id: $PROJECT_ID)"
  gcloud projects create "$PROJECT_ID" --name="$GC_PROJECT_DISPLAY_NAME" 
else
  echo "Project found with the display name: $GC_PROJECT_DISPLAY_NAME (Project ID: $PROJECT_ID)"
fi

GCP_SERVICE_ACCOUNT_MAIL=$(gcloud iam service-accounts list --project="${PROJECT_ID}" \
  --filter="name:'$GCP_SERVICE_ACCOUNT_NAME'" \
  --format="value(email)")

if [[ -z "$GCP_SERVICE_ACCOUNT_MAIL" ]]; then
  echo "No Service Account Found with the following name: $GCP_SERVICE_ACCOUNT_NAME. Creating..."
  # create project
  gcloud iam service-accounts create "$GCP_SERVICE_ACCOUNT_NAME" \
  --project "${PROJECT_ID}"
  GCP_SERVICE_ACCOUNT_MAIL="${GCP_SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
else
  echo "Service User found with name: $GCP_SERVICE_ACCOUNT_NAME (ID: $GCP_SERVICE_ACCOUNT_MAIL)"
fi

WI_POOL_ID=$(gcloud iam workload-identity-pools list \
  --filter="name:'$WI_POOL_NAME'" \
  --format="value(name)" \
  --project="${PROJECT_ID}" \
  --location="global")

if [[ -z "$WI_POOL_ID" ]]; then
  echo "No Workload Identity Pool Found with the following name: $WI_POOL_NAME. Creating..."
  # create project
  gcloud iam workload-identity-pools create "$WI_POOL_NAME" \
    --project="${PROJECT_ID}" \
    --location="global" \
    --display-name="GitHub Actions Pool"
  WI_POOL_ID=$(gcloud iam workload-identity-pools describe "$WI_POOL_NAME" \
    --project="${PROJECT_ID}" \
    --location="global" \
    --format="value(name)")
else
  echo "Workload Identity Pool found with name: $WI_POOL_NAME (ID: $WI_POOL_ID)"
fi

OIDC_NAME=${GITHUB_REPOSITORY#$GITHUB_USER/}

WI_OIDC_PROVIDER=$(gcloud iam workload-identity-pools providers list \
  --project="${PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="$WI_POOL_NAME" \
  --filter="name:'$OIDC_NAME'" \
  --format="value(name)")

# Add repo id assertion 
# https://github.com/google-github-actions/auth/blob/main/docs/SECURITY_CONSIDERATIONS.md
echo "Get current GitHub repository ID..."
GITHUB_REPO_ID=$(gh api repos/${GITHUB_REPOSITORY} --jq '.id') > /dev/null

if [[ -z "$WI_OIDC_PROVIDER" ]]; then
  echo "No OIDC Provider Found with the following name: $WI_POOL_NAME. Creating..."
  gcloud iam workload-identity-pools providers create-oidc "$OIDC_NAME" \
    --project="${PROJECT_ID}" \
    --location="global" \
    --workload-identity-pool="$WI_POOL_NAME" \
    --display-name="GitHub OIDC provider" \
    --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
    --attribute-condition="assertion.repository_owner == '${GITHUB_USER}' && assertion.repository_id == '${GITHUB_REPO_ID}'" \
    --issuer-uri="https://token.actions.githubusercontent.com"
    WI_OIDC_PROVIDER=$(gcloud iam workload-identity-pools providers describe "$OIDC_NAME" \
      --project="${PROJECT_ID}" \
      --location="global" \
      --workload-identity-pool="$WI_POOL_NAME" \
      --format="value(name)")
else
  echo "OIDC Provider found with name: $OIDC_NAME (ID: $WI_OIDC_PROVIDER)"
fi

# Allow authentications from the Workload Identity Pool to your Google Cloud Service Account.
gcloud iam service-accounts add-iam-policy-binding "${GCP_SERVICE_ACCOUNT_MAIL}" \
  --project="${PROJECT_ID}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/${WI_POOL_ID}/attribute.repository/${GITHUB_REPOSITORY}"

# grant service user owner rights to read/write resources in project
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --role="roles/owner" \
  --member="serviceAccount:${GCP_SERVICE_ACCOUNT_MAIL}"

# finally, enabled resource manager api for your project (required by terraform!)
gcloud services enable 'cloudresourcemanager.googleapis.com' --project "$PROJECT_ID"
gcloud services enable 'iamcredentials.googleapis.com' --project "$PROJECT_ID"
gcloud services enable 'androidpublisher.googleapis.com' --project "$PROJECT_ID"

echo "Setting GitHub secrets for GCP project and service account..."
gh secret set GCP_WORKLOAD_PROVIDER --body "$WI_OIDC_PROVIDER"
gh secret set GCP_PROJECT_ID --body "$PROJECT_ID"
gh secret set GCP_SERVICE_ACCOUNT_ID --body "$GCP_SERVICE_ACCOUNT_MAIL"

echo -e "${green}✓${nc} GCP setup finished successfully!"
