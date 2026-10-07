resource "azurerm_resource_group" "this" {
  name     = "rg-${var.fullstack_app.project_name}"
  location = var.fullstack_app.location
}

resource "azurerm_user_assigned_identity" "github" {
  name                = "id-${var.fullstack_app.project_name}-github"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_federated_identity_credential" "github_main" {
  name                      = "gh-branch-main"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  user_assigned_identity_id = azurerm_user_assigned_identity.github.id
  subject                   = "${var.fullstack_app.github_subject_claim}:ref:refs/heads/main"
}

resource "azurerm_federated_identity_credential" "github_pull_request" {
  name                      = "gh-pullrequest"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  user_assigned_identity_id = azurerm_user_assigned_identity.github.id
  subject                   = "${var.fullstack_app.github_subject_claim}:pull_request"
}
