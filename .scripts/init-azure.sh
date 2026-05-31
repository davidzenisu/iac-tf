#!/usr/bin/env bash
set -euo pipefail

CLOUDFLARE_SECRET_KEY=CLOUDFLARE_API_TOKEN
AZURE_TENANT_ID_KEY=AZURE_TENANT_ID
AZURE_SUBCRIPTION_ID_KEY=AZURE_SUBSCRIPTION_ID
AZURE_CLIENT_ID_KEY=AZURE_CLIENT_ID
AZURE_BACKEND_RG_KEY=AZURE_BACKEND_RG
AZURE_BACKEND_ST_KEY=AZURE_BACKEND_ST

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

require_az_login() {
  if az account show >/dev/null 2>&1; then
    echo "Already logged into Azure CLI."
  else
    echo "Azure CLI login required."
    az login --use-device-code
  fi
}

require_gh_login
require_az_login

read -p "Enter the name of your backend Azure Resource Group: " AZURE_BACKEND_RG_INPUT
read -p "Enter the name of your backend Azure Storage Account: " AZURE_BACKEND_ST_INPUT

echo "Validating storage account..."

storage_account=$(az storage account show -n "$AZURE_BACKEND_ST_INPUT" -g "$AZURE_BACKEND_RG_INPUT" 2>/dev/null)
if [ -n "$storage_account" ]; then
  echo -e "${green}✓${nc} Storage account validated!"
else
  echo -e "${red}Storage account does not exist! Please specify an existing storage account.${nc}"
  exit 1
fi

az_owner_name=$(gh repo view --json owner -q ".owner.login")
az_repo_name=$(gh repo view --json name -q ".name")

azure_backend_st_container_name="$az_owner_name"
storage_container=$(az storage container exists \
  -n "$azure_backend_st_container_name" \
  --auth-mode login \
  --blob-endpoint "$(echo "$storage_account" | jq -r '.primaryEndpoints.blob')")

if [ "$(echo "$storage_container" | jq -r '.exists')" = true ]; then
  echo -e "${green}✓${nc} Storage container validated!"
else
  echo -e "${red}Storage container $azure_backend_st_container_name does not exist! Please ensure a container with this name exists!${nc}"
  exit 1
fi

read -p "Are you want to set the secrets for Azure for your current repo and allow GitHub access to Azure? (yes/no) " yn
case "$yn" in
  yes ) echo "Ok, setting Azure secrets...";;
  no ) echo "Exiting..."; exit 1;;
  * ) echo "Invalid response. Exiting..."; exit 1;;
 esac

az_id_name="id-gh-${az_owner_name}-${az_repo_name}"
az_managed_identity=$(az identity show -n "$az_id_name" -g "$AZURE_BACKEND_RG_INPUT" 2>/dev/null || true)
if [ -n "$az_managed_identity" ]; then
  echo "Managed identity already exists."
else
  echo "Managed identity has to be created."
  echo "Creating managed identity..."
  az_managed_identity=$(az identity create -n "$az_id_name" -g "$AZURE_BACKEND_RG_INPUT")
fi

echo "Setting storage account permissions..."
az role assignment create \
  --role "Storage Blob Data Contributor" \
  --scope "$(echo "$storage_account" | jq -r '.id')" \
  --assignee-principal-type ServicePrincipal \
  --assignee-object-id "$(echo "$az_managed_identity" | jq -r '.principalId')"
echo -e "${green}✓${nc} Set storage account permissions for managed identity"

subscription_id=$(az account show --query id -o tsv)

echo "Setting subscription-level permissions..."
az role assignment create \
  --role "Contributor" \
  --scope "/subscriptions/$subscription_id" \
  --assignee-principal-type ServicePrincipal \
  --assignee-object-id "$(echo "$az_managed_identity" | jq -r '.principalId')"
echo -e "${green}✓${nc} Set Contributor role at subscription scope"

az role assignment create \
  --role "Role Based Access Control Administrator" \
  --scope "/subscriptions/$subscription_id" \
  --assignee-principal-type ServicePrincipal \
  --assignee-object-id "$(echo "$az_managed_identity" | jq -r '.principalId')"
echo -e "${green}✓${nc} Set Role Based Access Control Administrator role at subscription scope"

echo "Setting Azure federated credentials..."
az identity federated-credential create \
  -g "$AZURE_BACKEND_RG_INPUT" \
  --identity-name "$az_id_name" \
  -n "gh-branch-main" \
  --subject "repo:${az_owner_name}/${az_repo_name}:ref:refs/heads/main" \
  --issuer "https://token.actions.githubusercontent.com" \
  --audiences "api://AzureADTokenExchange"
echo -e "${green}✓${nc} Set federated credential for main branch"

az identity federated-credential create \
  -g "$AZURE_BACKEND_RG_INPUT" \
  --identity-name "$az_id_name" \
  -n "gh-pullrequest" \
  --subject "repo:${az_owner_name}/${az_repo_name}:pull_request" \
  --issuer "https://token.actions.githubusercontent.com" \
  --audiences "api://AzureADTokenExchange"
echo -e "${green}✓${nc} Set federated credential for pull request"

echo "Setting Azure secrets..."
gh secret set "$AZURE_TENANT_ID_KEY" --body "$(az account show | jq -r '.tenantId')"
gh secret set "$AZURE_SUBCRIPTION_ID_KEY" --body "$(az account show | jq -r '.id')"
gh secret set "$AZURE_CLIENT_ID_KEY" --body "$(echo "$az_managed_identity" | jq -r '.clientId')"
gh secret set "$AZURE_BACKEND_RG_KEY" --body "$AZURE_BACKEND_RG_INPUT"
gh secret set "$AZURE_BACKEND_ST_KEY" --body "$AZURE_BACKEND_ST_INPUT"

echo "Azure setup finished successfully!"
