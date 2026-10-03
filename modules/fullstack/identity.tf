resource "azurerm_resource_group" "this" {
  for_each = var.fullstack_apps

  name     = "rg-${each.value.project_name}"
  location = each.value.location
}

resource "azurerm_user_assigned_identity" "github" {
  for_each = var.fullstack_apps

  name                = "id-${each.value.project_name}-github"
  location            = azurerm_resource_group.this[each.key].location
  resource_group_name = azurerm_resource_group.this[each.key].name
}

resource "azurerm_federated_identity_credential" "github_main" {
  for_each = var.fullstack_apps

  name                      = "gh-branch-main"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  user_assigned_identity_id = azurerm_user_assigned_identity.github[each.key].id
  subject                   = "${each.value.github_subject_claim}:ref:refs/heads/main"
}

resource "azurerm_federated_identity_credential" "github_pull_request" {
  for_each = var.fullstack_apps

  name                      = "gh-pullrequest"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  user_assigned_identity_id = azurerm_user_assigned_identity.github[each.key].id
  subject                   = "${each.value.github_subject_claim}:pull_request"
}
