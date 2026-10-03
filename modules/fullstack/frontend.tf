resource "azurerm_static_web_app" "this" {
  for_each = local.frontend_apps

  name                = "swa-${each.value.project_name}-${local.suffixes[each.key]}"
  location            = azurerm_resource_group.this[each.key].location
  resource_group_name = azurerm_resource_group.this[each.key].name
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

resource "azurerm_role_assignment" "github_static_web_app" {
  for_each = local.frontend_apps

  scope                = azurerm_static_web_app.this[each.key].id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.github[each.key].principal_id
}

resource "cloudflare_record" "static_web_app" {
  for_each = local.custom_domain_apps

  zone_id = var.zone_id
  name    = each.value.custom_domain
  content = azurerm_static_web_app.this[each.key].default_host_name
  type    = "CNAME"
  proxied = false
}

resource "time_sleep" "custom_domain_wait" {
  for_each = local.custom_domain_apps

  create_duration  = "300s"
  destroy_duration = "0s"

  depends_on = [
    cloudflare_record.static_web_app,
  ]
}

resource "azurerm_static_web_app_custom_domain" "this" {
  for_each = local.custom_domain_apps

  static_web_app_id = azurerm_static_web_app.this[each.key].id
  domain_name       = "${each.value.custom_domain}.${var.zone_name}"
  validation_type   = "cname-delegation"

  depends_on = [
    cloudflare_record.static_web_app,
    time_sleep.custom_domain_wait,
  ]
}
