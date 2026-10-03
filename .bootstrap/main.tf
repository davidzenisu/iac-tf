
resource "google_project" "bootstrap" {
  project_id          = var.gcp_project_id
  name                = var.gcp_project_name
  billing_account     = var.gcp_billing_account_id
  auto_create_network = false
}

data "azurerm_client_config" "current" {}

resource "azurerm_storage_account" "backend" {
  name                            = var.azure_backend_storage_account
  resource_group_name             = var.azure_backend_resource_group
  location                        = var.azure_location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
}

resource "azurerm_storage_container" "terraform_state" {
  name                  = lower(var.github_owner)
  storage_account_id    = azurerm_storage_account.backend.id
  container_access_type = "private"
}

resource "azurerm_user_assigned_identity" "github_actions" {
  name                = "id-gh-${var.github_owner}-${var.github_repository}"
  resource_group_name = var.azure_backend_resource_group
  location            = var.azure_location
}

resource "azurerm_role_assignment" "storage_blob_contributor" {
  scope                = azurerm_storage_account.backend.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.github_actions.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "storage_backup_blob_contributor" {
  scope                = azurerm_storage_account.backend.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
  principal_type       = "User"
}

resource "time_sleep" "storage_blob_rbac_propagation" {
  create_duration = "30s"

  triggers = {
    role_assignment_id = azurerm_role_assignment.storage_backup_blob_contributor.id
  }
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
  display_name = "GitHub Actions Workload Identity Federation ${var.github_owner}/${var.github_repository}"

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
    "CAN_EDIT_CONNECTED_APPS_GLOBAL",
    "CAN_EDIT_GAMES_GLOBAL",
    "CAN_MANAGE_APP_CONTENT_GLOBAL",
    "CAN_MANAGE_DEEPLINKS_GLOBAL",
    "CAN_MANAGE_DRAFT_APPS_GLOBAL",
    "CAN_MANAGE_ORDERS_GLOBAL",
    "CAN_MANAGE_PERMISSIONS_GLOBAL",
    "CAN_MANAGE_PUBLIC_APKS_GLOBAL",
    "CAN_MANAGE_PUBLIC_LISTING_GLOBAL",
    "CAN_MANAGE_TRACK_APKS_GLOBAL",
    "CAN_MANAGE_TRACK_USERS_GLOBAL",
    "CAN_PUBLISH_GAMES_GLOBAL",
    "CAN_REPLY_TO_REVIEWS_GLOBAL",
    "CAN_VIEW_APP_QUALITY_GLOBAL",
    "CAN_VIEW_CONNECTED_APPS_GLOBAL",
    "CAN_VIEW_FINANCIAL_DATA_GLOBAL",
    "CAN_VIEW_NON_FINANCIAL_DATA_GLOBAL",
  ]
}

resource "auth0_client" "github_actions" {
  name        = "Auth0 Terraform Provider"
  description = "Auth0 Terraform Provider M2M via GitHub Actions"
  app_type    = "non_interactive"

  jwt_configuration {
    alg = "RS256"
  }
}

resource "auth0_client_credentials" "github_actions" {
  client_id             = auth0_client.github_actions.id
  authentication_method = "client_secret_basic"
}

