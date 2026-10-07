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

# State migration for fullstack resources from the single map-driven module
# instance to one module instance per app.
moved {
  from = module.fullstack.azurerm_resource_group.this["drawing-duel"]
  to   = module.fullstack["drawing-duel"].azurerm_resource_group.this
}

moved {
  from = module.fullstack.azurerm_user_assigned_identity.github["drawing-duel"]
  to   = module.fullstack["drawing-duel"].azurerm_user_assigned_identity.github
}

moved {
  from = module.fullstack.azurerm_federated_identity_credential.github_main["drawing-duel"]
  to   = module.fullstack["drawing-duel"].azurerm_federated_identity_credential.github_main
}

moved {
  from = module.fullstack.azurerm_federated_identity_credential.github_pull_request["drawing-duel"]
  to   = module.fullstack["drawing-duel"].azurerm_federated_identity_credential.github_pull_request
}

moved {
  from = module.fullstack.azurerm_key_vault.this["drawing-duel"]
  to   = module.fullstack["drawing-duel"].azurerm_key_vault.this
}

moved {
  from = module.fullstack.azurerm_role_assignment.github_key_vault["drawing-duel"]
  to   = module.fullstack["drawing-duel"].azurerm_role_assignment.github_key_vault
}

moved {
  from = module.fullstack.azurerm_role_assignment.terraform_key_vault["drawing-duel"]
  to   = module.fullstack["drawing-duel"].azurerm_role_assignment.terraform_key_vault
}

moved {
  from = module.fullstack.time_sleep.key_vault_rbac_propagation["drawing-duel"]
  to   = module.fullstack["drawing-duel"].time_sleep.key_vault_rbac_propagation
}

moved {
  from = module.fullstack.azurerm_key_vault_secret.resource_group_name["drawing-duel"]
  to   = module.fullstack["drawing-duel"].azurerm_key_vault_secret.resource_group_name
}

moved {
  from = module.fullstack.azurerm_role_assignment.github_static_web_app["drawing-duel"]
  to   = module.fullstack["drawing-duel"].azurerm_role_assignment.github_static_web_app[0]
}

moved {
  from = module.fullstack.azurerm_static_web_app.this["drawing-duel"]
  to   = module.fullstack["drawing-duel"].azurerm_static_web_app.this[0]
}

moved {
  from = module.fullstack.azurerm_key_vault_secret.swa_name["drawing-duel"]
  to   = module.fullstack["drawing-duel"].azurerm_key_vault_secret.swa_name[0]
}

moved {
  from = module.fullstack.cloudflare_record.static_web_app["drawing-duel"]
  to   = module.fullstack["drawing-duel"].cloudflare_record.static_web_app[0]
}

moved {
  from = module.fullstack.time_sleep.custom_domain_wait["drawing-duel"]
  to   = module.fullstack["drawing-duel"].time_sleep.custom_domain_wait[0]
}

moved {
  from = module.fullstack.azurerm_static_web_app_custom_domain.this["drawing-duel"]
  to   = module.fullstack["drawing-duel"].azurerm_static_web_app_custom_domain.this[0]
}

moved {
  from = module.fullstack.azurerm_role_assignment.function_key_vault["drawing-duel"]
  to   = module.fullstack["drawing-duel"].azurerm_role_assignment.function_key_vault[0]
}

moved {
  from = module.fullstack.azurerm_key_vault_secret.function_app_name["drawing-duel"]
  to   = module.fullstack["drawing-duel"].azurerm_key_vault_secret.function_app_name[0]
}

moved {
  from = module.fullstack.azurerm_key_vault_secret.storage_account_name["drawing-duel"]
  to   = module.fullstack["drawing-duel"].azurerm_key_vault_secret.storage_account_name[0]
}

moved {
  from = module.fullstack.azurerm_storage_account.this["drawing-duel"]
  to   = module.fullstack["drawing-duel"].azurerm_storage_account.this[0]
}

moved {
  from = module.fullstack.azurerm_service_plan.this["drawing-duel"]
  to   = module.fullstack["drawing-duel"].azurerm_service_plan.this[0]
}

moved {
  from = module.fullstack.azurerm_user_assigned_identity.function["drawing-duel"]
  to   = module.fullstack["drawing-duel"].azurerm_user_assigned_identity.function[0]
}

moved {
  from = module.fullstack.azurerm_role_assignment.function_storage["drawing-duel"]
  to   = module.fullstack["drawing-duel"].azurerm_role_assignment.function_storage[0]
}

moved {
  from = module.fullstack.azurerm_function_app_flex_consumption.this["drawing-duel"]
  to   = module.fullstack["drawing-duel"].azurerm_function_app_flex_consumption.this[0]
}

moved {
  from = module.fullstack.azapi_update_resource.function_key_vault_reference_identity["drawing-duel"]
  to   = module.fullstack["drawing-duel"].azapi_update_resource.function_key_vault_reference_identity[0]
}

moved {
  from = module.fullstack.azurerm_role_assignment.github_function["drawing-duel"]
  to   = module.fullstack["drawing-duel"].azurerm_role_assignment.github_function[0]
}

moved {
  from = module.fullstack.cloudflare_record.function_app["drawing-duel"]
  to   = module.fullstack["drawing-duel"].cloudflare_record.function_app[0]
}

moved {
  from = module.fullstack.time_sleep.backend_custom_domain_wait["drawing-duel"]
  to   = module.fullstack["drawing-duel"].time_sleep.backend_custom_domain_wait[0]
}

moved {
  from = module.fullstack.azurerm_app_service_custom_hostname_binding.this["drawing-duel"]
  to   = module.fullstack["drawing-duel"].azurerm_app_service_custom_hostname_binding.this[0]
}

moved {
  from = module.fullstack.azapi_resource.backend_managed_cert["drawing-duel"]
  to   = module.fullstack["drawing-duel"].azapi_resource.backend_managed_cert[0]
}

moved {
  from = module.fullstack.azapi_update_resource.backend_https_binding["drawing-duel"]
  to   = module.fullstack["drawing-duel"].azapi_update_resource.backend_https_binding[0]
}

moved {
  from = module.fullstack.random_password.this["drawing-duel"]
  to   = module.fullstack["drawing-duel"].random_password.this[0]
}

moved {
  from = module.fullstack.supabase_project.this["drawing-duel"]
  to   = module.fullstack["drawing-duel"].supabase_project.this[0]
}

moved {
  from = module.fullstack.azurerm_key_vault_secret.supabase_db_password["drawing-duel"]
  to   = module.fullstack["drawing-duel"].azurerm_key_vault_secret.supabase_db_password[0]
}

moved {
  from = module.fullstack.azurerm_key_vault_secret.database_url["drawing-duel"]
  to   = module.fullstack["drawing-duel"].azurerm_key_vault_secret.database_url[0]
}

moved {
  from = module.fullstack.azurerm_storage_container.this["drawing-duel"]
  to   = module.fullstack["drawing-duel"].azurerm_storage_container.this[0]
}

moved {
  from = module.fullstack.auth0_client.this["drawing-duel"]
  to   = module.fullstack["drawing-duel"].auth0_client.this[0]
}

moved {
  from = module.fullstack.azurerm_key_vault_secret.auth0_domain["drawing-duel"]
  to   = module.fullstack["drawing-duel"].azurerm_key_vault_secret.auth0_domain[0]
}

moved {
  from = module.fullstack.azurerm_key_vault_secret.auth0_client_id["drawing-duel"]
  to   = module.fullstack["drawing-duel"].azurerm_key_vault_secret.auth0_client_id[0]
}

moved {
  from = module.fullstack.azurerm_key_vault_secret.frontend_custom_domain["drawing-duel"]
  to   = module.fullstack["drawing-duel"].azurerm_key_vault_secret.frontend_custom_domain[0]
}

moved {
  from = module.fullstack.azurerm_key_vault_secret.api_custom_domain["drawing-duel"]
  to   = module.fullstack["drawing-duel"].azurerm_key_vault_secret.api_custom_domain[0]
}
