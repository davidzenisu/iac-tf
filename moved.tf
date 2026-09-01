# State migration for AVM Static Web App module -> explicit AzureRM resources.
# These entries reflect the resource structure used before the refactor in webapp.tf.

moved {
  from = module.static_web_app["portfolio"].azurerm_static_web_app.this
  to   = azurerm_static_web_app.static_web_app["portfolio"]
}

moved {
  from = module.static_web_app["portfolio"].azurerm_role_assignment.this["gh_identity"]
  to   = azurerm_role_assignment.static_web_app_github_identity["portfolio"]
}

moved {
  from = module.static_web_app["events"].azurerm_static_web_app.this
  to   = azurerm_static_web_app.static_web_app["events"]
}

moved {
  from = module.static_web_app["events"].azurerm_role_assignment.this["gh_identity"]
  to   = azurerm_role_assignment.static_web_app_github_identity["events"]
}

moved {
  from = module.static_web_app["radio-guesser"].azurerm_static_web_app.this
  to   = azurerm_static_web_app.static_web_app["radio-guesser"]
}

moved {
  from = module.static_web_app["radio-guesser"].azurerm_role_assignment.this["gh_identity"]
  to   = azurerm_role_assignment.static_web_app_github_identity["radio-guesser"]
}

moved {
  from = module.static_web_app["gods-pet"].azurerm_static_web_app.this
  to   = azurerm_static_web_app.static_web_app["gods-pet"]
}

moved {
  from = module.static_web_app["gods-pet"].azurerm_role_assignment.this["gh_identity"]
  to   = azurerm_role_assignment.static_web_app_github_identity["gods-pet"]
}
