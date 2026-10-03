data "azurerm_client_config" "current" {}

locals {
  suffixes = {
    for key, app in var.fullstack_apps :
    key => substr(sha1("${data.azurerm_client_config.current.subscription_id}/${app.project_name}"), 0, 6)
  }

  key_vault_apps = {
    for key, app in var.fullstack_apps : key => app
    if app.frontend || app.backend
  }

  frontend_apps = {
    for key, app in var.fullstack_apps : key => app
    if app.frontend
  }

  backend_apps = {
    for key, app in var.fullstack_apps : key => app
    if app.backend
  }

  storage_apps = {
    for key, app in var.fullstack_apps : key => app
    if app.storage
  }

  database_apps = {
    for key, app in var.fullstack_apps : key => app
    if app.database
  }

  auth_apps = {
    for key, app in var.fullstack_apps : key => app
    if app.auth
  }

  custom_domain_apps = {
    for key, app in var.fullstack_apps : key => app
    if app.frontend && app.custom_domain != null
  }
}
