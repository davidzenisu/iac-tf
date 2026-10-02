terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
    googleplay = {
      source  = "Oliver-Binns/googleplay"
      version = "~> 0.6"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

provider "azurerm" {
  features {}
  use_cli = true
}

provider "google" {
  project = var.gcp_project_id
}

provider "googleplay" {
  developer_id = var.play_store_developer_id
}

provider "github" {
  owner = var.github_owner
}

resource "google_project" "bootstrap" {
  project_id          = var.gcp_project_id
  name                = var.gcp_project_name
  billing_account     = var.gcp_billing_account_id
  auto_create_network = false
}

data "azurerm_client_config" "current" {}

data "azurerm_storage_account" "backend" {
  name                = var.azure_backend_storage_account
  resource_group_name = var.azure_backend_resource_group
}

resource "azurerm_user_assigned_identity" "github_actions" {
  name                = "id-gh-${var.github_owner}-${var.github_repository}"
  resource_group_name = var.azure_backend_resource_group
  location            = data.azurerm_storage_account.backend.location
}

resource "azurerm_role_assignment" "storage_blob_contributor" {
  scope                = data.azurerm_storage_account.backend.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.github_actions.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "subscription_contributor" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.github_actions.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "subscription_rbac_admin" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Role Based Access Control Administrator"
  principal_id         = azurerm_user_assigned_identity.github_actions.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_federated_identity_credential" "main" {
  name                      = "gh-branch-main"
  user_assigned_identity_id = azurerm_user_assigned_identity.github_actions.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = "repo:${var.github_owner}/${var.github_repository}:ref:refs/heads/main"
}

resource "azurerm_federated_identity_credential" "pull_request" {
  name                      = "gh-pullrequest"
  user_assigned_identity_id = azurerm_user_assigned_identity.github_actions.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = "repo:${var.github_owner}/${var.github_repository}:pull_request"
}

resource "google_project_service" "bootstrap_apis" {
  for_each = toset([
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "androidpublisher.googleapis.com",
  ])

  project            = var.gcp_project_id
  service            = each.value
  disable_on_destroy = false

  depends_on = [google_project.bootstrap]
}

resource "google_service_account" "github_actions" {
  project      = var.gcp_project_id
  account_id   = var.gcp_service_account_name
  display_name = "GitHub Actions Workload Identity Federation"

  depends_on = [google_project_service.bootstrap_apis]
}

resource "google_project_iam_member" "github_actions_owner" {
  project = var.gcp_project_id
  role    = "roles/owner"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.gcp_project_id
  workload_identity_pool_id = "gh-oidc"
  display_name              = "GitHub Actions Pool"

  depends_on = [google_project_service.bootstrap_apis]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.gcp_project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = var.github_repository
  display_name                       = "GitHub OIDC provider"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.actor"            = "assertion.actor"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.repository_id"    = "assertion.repository_id"
  }

  attribute_condition = "assertion.repository_owner == '${var.github_owner}' && assertion.repository_id == '${var.github_repository_id}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  depends_on = [google_project_service.bootstrap_apis]
}

resource "google_service_account_iam_member" "github_actions_wif" {
  service_account_id = google_service_account.github_actions.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_owner}/${var.github_repository}"
}

resource "googleplay_user" "github_actions" {
  email = google_service_account.github_actions.email

  global_permissions = [
    "CAN_MANAGE_PERMISSIONS_GLOBAL",
  ]
}

resource "github_actions_secret" "azure_tenant_id" {
  repository  = var.github_repository
  secret_name = "AZURE_TENANT_ID"
  value       = data.azurerm_client_config.current.tenant_id
}

resource "github_actions_secret" "azure_subscription_id" {
  repository  = var.github_repository
  secret_name = "AZURE_SUBSCRIPTION_ID"
  value       = data.azurerm_client_config.current.subscription_id
}

resource "github_actions_secret" "azure_client_id" {
  repository  = var.github_repository
  secret_name = "AZURE_CLIENT_ID"
  value       = azurerm_user_assigned_identity.github_actions.client_id
}

resource "github_actions_secret" "azure_backend_resource_group" {
  repository  = var.github_repository
  secret_name = "AZURE_BACKEND_RG"
  value       = var.azure_backend_resource_group
}

resource "github_actions_secret" "azure_backend_storage_account" {
  repository  = var.github_repository
  secret_name = "AZURE_BACKEND_ST"
  value       = var.azure_backend_storage_account
}

resource "github_actions_secret" "cloudflare_api_token" {
  repository  = var.github_repository
  secret_name = "CLOUDFLARE_API_TOKEN"
  value       = var.cloudflare_api_token
}

resource "github_actions_secret" "gcp_workload_provider" {
  repository  = var.github_repository
  secret_name = "GCP_WORKLOAD_PROVIDER"
  value       = google_iam_workload_identity_pool_provider.github.name
}

resource "github_actions_secret" "gcp_project_id" {
  repository  = var.github_repository
  secret_name = "GCP_PROJECT_ID"
  value       = var.gcp_project_id
}

resource "github_actions_secret" "gcp_service_account_id" {
  repository  = var.github_repository
  secret_name = "GCP_SERVICE_ACCOUNT_ID"
  value       = google_service_account.github_actions.email
}
