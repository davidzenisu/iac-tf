resource "azurerm_static_web_app" "this" {
  count = var.fullstack_app.frontend ? 1 : 0

  name                = "swa-${var.fullstack_app.project_name}-${local.suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
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
  count = var.fullstack_app.frontend ? 1 : 0

  scope                = azurerm_static_web_app.this[0].id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.github.principal_id
}

resource "cloudflare_record" "static_web_app" {
  count = var.fullstack_app.frontend && local.has_custom_domain ? 1 : 0

  zone_id = var.zone_id
  name    = var.fullstack_app.custom_domain
  content = azurerm_static_web_app.this[0].default_host_name
  type    = "CNAME"
  proxied = false
}

resource "time_sleep" "custom_domain_wait" {
  count = var.fullstack_app.frontend && local.has_custom_domain ? 1 : 0

  create_duration  = "300s"
  destroy_duration = "0s"

  depends_on = [
    cloudflare_record.static_web_app,
  ]
}

resource "azurerm_static_web_app_custom_domain" "this" {
  count = var.fullstack_app.frontend && local.has_custom_domain ? 1 : 0

  static_web_app_id = azurerm_static_web_app.this[0].id
  domain_name       = "${var.fullstack_app.custom_domain}.${var.zone_name}"
  validation_type   = "cname-delegation"

  depends_on = [
    cloudflare_record.static_web_app,
    time_sleep.custom_domain_wait,
  ]
}
