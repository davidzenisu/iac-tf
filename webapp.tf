resource "azurerm_resource_group" "static_web_app" {
  for_each = var.static_web_apps

  name     = each.value.resource_group_name
  location = each.value.location
}

resource "azurerm_user_assigned_identity" "static_web_app" {
  for_each = var.static_web_apps

  location            = azurerm_resource_group.static_web_app[each.key].location
  name                = "id-${each.value.name}"
  resource_group_name = azurerm_resource_group.static_web_app[each.key].name
}

resource "azurerm_federated_identity_credential" "static_web_app_main_branch" {
  for_each = var.static_web_apps

  name                      = "gh-branch-main"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  user_assigned_identity_id = azurerm_user_assigned_identity.static_web_app[each.key].id
  subject                   = "repo:${each.value.source_repo}:ref:refs/heads/main"
}

resource "azurerm_federated_identity_credential" "static_web_app_pr" {
  for_each = var.static_web_apps

  name                      = "gh-pullrequest"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  user_assigned_identity_id = azurerm_user_assigned_identity.static_web_app[each.key].id
  subject                   = "repo:${each.value.source_repo}:pull_request"
}

# static web app
module "static_web_app" {
  for_each = var.static_web_apps

  source  = "Azure/avm-res-web-staticsite/azurerm"
  version = "~> 0.6.2"

  name                = each.value.name
  location            = azurerm_resource_group.static_web_app[each.key].location
  resource_group_name = azurerm_resource_group.static_web_app[each.key].name
  app_settings = {

  }

  role_assignments = {
    "gh_identity" = {
      principal_id               = azurerm_user_assigned_identity.static_web_app[each.key].principal_id
      role_definition_id_or_name = "Contributor" #no custom role exists
      description                = "GitHub Actions identity for Static Web App"
    }
  }


  enable_telemetry = false
}

resource "cloudflare_record" "static_web_app" {
  for_each = var.static_web_apps

  zone_id = data.cloudflare_zone.this["default"].id
  name    = each.value.custom_domain
  content = module.static_web_app[each.key].resource_uri
  type    = "CNAME"
  proxied = false
}

resource "time_sleep" "static_web_app_custom_domain_wait" {
  count = length(
    [for v in var.static_web_apps : v if v.custom_domain != null]
  ) != 0 ? 1 : 0

  create_duration  = "300s"
  destroy_duration = "0s"

  depends_on = [
    cloudflare_record.static_web_app,
  ]
}

# can't be created via module because it's evaluated immediately!
resource "azurerm_static_web_app_custom_domain" "static_web_app" {
  for_each = {
    for k, v in var.static_web_apps : k => v if v.custom_domain != null
  }

  static_web_app_id = module.static_web_app[each.key].resource_id
  domain_name       = "${each.value.custom_domain}.${var.zone_name}"
  validation_type   = "cname-delegation"

  depends_on = [
    cloudflare_record.static_web_app,
    time_sleep.static_web_app_custom_domain_wait,
  ]
}
