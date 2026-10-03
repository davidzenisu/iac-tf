module "fullstack" {
  source = "./modules/fullstack"

  fullstack_apps = var.fullstack_apps
  zone_name      = var.zone_name
  zone_id        = try(data.cloudflare_zone.this["default"].id, null)

  providers = {
    auth0      = auth0
    azurerm    = azurerm
    cloudflare = cloudflare
    random     = random
    supabase   = supabase
    time       = time
  }
}

output "fullstack_github_credentials" {
  description = "Client IDs and tenant/subscription identifiers for GitHub Actions OIDC login. No client secret is created."
  value       = module.fullstack.github_credentials
}

output "fullstack_auth0_client_ids" {
  description = "Client IDs for the fullstack Auth0 applications."
  value       = module.fullstack.auth0_client_ids
}

output "fullstack_supabase_project_ids" {
  description = "Project references for the fullstack Supabase projects."
  value       = module.fullstack.supabase_project_ids
}
