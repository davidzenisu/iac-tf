variable "fullstack_app" {
  description = "A fullstack project and the cloud resources enabled for it."
  type = object({
    project_name             = string
    location                 = string
    github_subject_claim     = string
    function_runtime_name    = optional(string)
    function_runtime_version = optional(string)
    custom_domain            = optional(string)
    frontend                 = optional(bool, true)
    backend                  = optional(bool, true)
    storage                  = optional(bool, true)
    database                 = optional(bool, true)
    auth                     = optional(bool, true)
    auth0_permissions        = optional(map(object({ description = optional(string) })), {})
    supabase_organization_id = optional(string)
    supabase_region          = optional(string, "eu-west-1")
  })

  validation {
    condition     = !contains(keys(var.fullstack_app.auth0_permissions), "read:api")
    error_message = "auth0_permissions must not redefine the built-in read:api permission."
  }
}

variable "auth0_user_role_id" {
  description = "Tenant-wide Auth0 role ID assigned to new users and authorized for this app's API."
  type        = string
  default     = null

  validation {
    condition     = !var.fullstack_app.auth || var.auth0_user_role_id != null
    error_message = "auth0_user_role_id must be provided when auth is enabled."
  }
}

variable "zone_name" {
  description = "DNS zone suffix for custom frontend domains."
  type        = string
  default     = null
}

variable "zone_id" {
  description = "Cloudflare zone ID used to create custom frontend DNS records."
  type        = string
  default     = null
}

variable "auth0_connection_ids" {
  description = "Auth0 connections to enable for this app's SPA and docs clients, as a map from an arbitrary key (e.g. the provider name) to the connection ID. Only used when auth is enabled."
  type        = map(string)
  default     = {}
}
