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
  subject                   = "${each.value.github_subject_claim}:ref:refs/heads/main"
}

resource "azurerm_federated_identity_credential" "static_web_app_pr" {
  for_each = var.static_web_apps

  name                      = "gh-pullrequest"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  user_assigned_identity_id = azurerm_user_assigned_identity.static_web_app[each.key].id
  subject                   = "${each.value.github_subject_claim}:pull_request"
}

resource "azurerm_static_web_app" "static_web_app" {
  for_each = var.static_web_apps

  name                = each.value.name
  location            = azurerm_resource_group.static_web_app[each.key].location
  resource_group_name = azurerm_resource_group.static_web_app[each.key].name
  sku_tier            = "Free"
  sku_size            = "Free"

  lifecycle {
    ignore_changes = [
      app_settings,
      repository_branch,
      repository_url,
    ]
  }
}

resource "azurerm_role_assignment" "static_web_app_github_identity" {
  for_each = var.static_web_apps

  scope                = azurerm_static_web_app.static_web_app[each.key].id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.static_web_app[each.key].principal_id
}

resource "cloudflare_record" "static_web_app" {
  for_each = var.static_web_apps

  zone_id = data.cloudflare_zone.this["default"].id
  name    = each.value.custom_domain
  content = azurerm_static_web_app.static_web_app[each.key].default_host_name
  type    = "CNAME"
  proxied = false
}

resource "time_sleep" "static_web_app_custom_domain_wait" {
  for_each = var.static_web_apps

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

  static_web_app_id = azurerm_static_web_app.static_web_app[each.key].id
  domain_name       = "${each.value.custom_domain}.${var.zone_name}"
  validation_type   = "cname-delegation"

  depends_on = [
    cloudflare_record.static_web_app,
    time_sleep.static_web_app_custom_domain_wait,
  ]
}
