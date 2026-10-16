variable "zone_name" {
  description = "Name of the managed zone. Ideally passed as senstive environment variables (e.g. GitHub secret)."
  type        = string
  default     = null
}

variable "dns_records" {
  type = map(object({
    name    = string
    content = string
    type    = string
    proxied = optional(bool, false)
  }))
  default = {}
  validation {
    condition     = length(var.dns_records) == 0 || var.zone_name != null
    error_message = "DNS records can only be configured, if a valid zone name is provided."
  }
  description = <<DESCRIPTION
A map of DNS records to create. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

- `name` - The name of the managed subdomain.
- `type` - The type of the record (A, CNAME, TXT, etc.).
- `content` - The content of the record.
- `proxied` - (Optional) Whether the entry is served using Cloudflare's proxy. May cause compatibility issues if set to true. Defaults to false.
DESCRIPTION
}

variable "static_web_apps" {
  type = map(object({
    name                 = string
    resource_group_name  = string
    location             = string
    github_subject_claim = string
    custom_domain        = optional(string)
  }))
  default     = {}
  description = <<DESCRIPTION
A map of Azure Static Web Apps and their GitHub Actions federation settings. The map key is deliberately arbitrary to avoid issues where map keys may be unknown at plan time.

- `name` - The name of the Azure Static Web App.
- `resource_group_name` - The name of the resource group containing the Static Web App and its user-assigned identity.
- `location` - The Azure region where the resources are created.
- `github_subject_claim` - The GitHub repository owner and name used to build the immutable OIDC subject claims for the main branch and pull requests. See [OpenID Connect reference - GitHub Docs](https://docs.github.com/en/actions/reference/security/oidc#immutable-subject-claims).
- `custom_domain` - (Optional) The subdomain to associate with the Static Web App. Defaults to null.
DESCRIPTION
}

variable "fullstack_apps" {
  description = "Fullstack projects and the cloud resources enabled for each project."
  type = map(object({
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
    display_name             = optional(string)
    auth0_permissions        = optional(map(object({ description = optional(string) })), {})
    supabase_organization_id = optional(string)
    supabase_region          = optional(string, "eu-west-1")
  }))
  default = {}

  validation {
    condition = alltrue([
      for app in values(var.fullstack_apps) :
      can(regex("^[a-z0-9][a-z0-9-]{0,18}[a-z0-9]$", app.project_name))
    ])
    error_message = "Each project_name must be 2-20 lowercase letters, numbers, or hyphens, and start and end with a letter or number."
  }

  validation {
    condition = length(distinct([
      for app in values(var.fullstack_apps) : app.project_name
    ])) == length(var.fullstack_apps)
    error_message = "Each project_name in fullstack_apps must be unique."
  }

  validation {
    condition = alltrue([
      for app in values(var.fullstack_apps) :
      (!app.storage || app.backend) &&
      (!app.auth || (app.frontend && app.backend && app.custom_domain != null)) &&
      (!app.database || app.supabase_organization_id != null)
    ])
    error_message = "Storage requires backend=true; auth requires frontend=true, backend=true, and custom_domain; database=true requires supabase_organization_id."
  }

  validation {
    condition = alltrue([
      for app in values(var.fullstack_apps) :
      !app.backend || try(
        length(trimspace(app.function_runtime_name)) > 0 &&
        length(trimspace(app.function_runtime_version)) > 0,
        false
      )
    ])
    error_message = "Each fullstack app with backend=true must provide a non-empty function_runtime_name and function_runtime_version."
  }

  validation {
    condition = (
      var.zone_name != null ||
      alltrue([
        for app in values(var.fullstack_apps) :
        app.custom_domain == null
      ])
    )
    error_message = "A zone_name must be configured when a fullstack app uses a custom_domain."
  }
}

variable "github_org_id" {
  description = "The GitHub organization id. Could be passed dynamically from the GitHub workflow."
  type        = string
  default     = null
}

variable "play_store_developer_id" {
  description = "The Google Play Developer ID. Ideally passed as senstive environment variables (e.g. GitHub secret)."
  type        = string
  default     = null
}

variable "android_apps" {
  description = "A map of Android apps with the immutable GitHub OIDC subject token that may impersonate a dedicated service account."
  type = map(object({
    gh_oidc_subject = string
    android_app_id  = string
  }))
  default = {}
}

variable "auth0_google_client_id" {
  description = "Google OAuth client ID for the Auth0 Google connection. The pipeline sets it from the bootstrap Key Vault secret auth0-google-client-id when that secret exists."
  type        = string
  default     = null
}

variable "auth0_google_client_secret" {
  description = "Google OAuth client secret for the Auth0 Google connection. The pipeline sets it from the bootstrap Key Vault secret auth0-google-client-secret when that secret exists."
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = (var.auth0_google_client_id == null) == (var.auth0_google_client_secret == null)
    error_message = "Set both auth0_google_client_id and auth0_google_client_secret, or neither."
  }
}

variable "auth0_github_client_id" {
  description = "GitHub OAuth client ID for the Auth0 GitHub connection. The pipeline sets it from the bootstrap Key Vault secret auth0-github-client-id when that secret exists."
  type        = string
  default     = null
}

variable "auth0_github_client_secret" {
  description = "GitHub OAuth client secret for the Auth0 GitHub connection. The pipeline sets it from the bootstrap Key Vault secret auth0-github-client-secret when that secret exists."
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = (var.auth0_github_client_id == null) == (var.auth0_github_client_secret == null)
    error_message = "Set both auth0_github_client_id and auth0_github_client_secret, or neither."
  }
}

variable "auth0_google_connection_id" {
  description = "ID (con_...) of the google-oauth2 connection that comes with new Auth0 tenants. When set, Terraform imports it as the Google social connection instead of creating a new one. Only takes effect while the Google client id and secret are set."
  type        = string
  default     = null

  validation {
    condition     = var.auth0_google_connection_id == null || can(regex("^con_[A-Za-z0-9]+$", var.auth0_google_connection_id))
    error_message = "auth0_google_connection_id must be an Auth0 connection ID like con_XXXXXXXXXXXXXXXX."
  }
}

variable "auth0_branding" {
  description = <<DESCRIPTION
Tenant-wide branding of the Auth0 login pages. Every attribute is optional; unset attributes keep the tenant's current value.

- `friendly_name` - (Optional) Tenant name shown on the login page ("Log in to <name>").
- `picture_url` - (Optional) Tenant logo, used where no branding logo is set. Recommended size 150x150 px.
- `logo_url` - (Optional) Logo shown on the login pages.
- `favicon_url` - (Optional) Favicon of the login pages.
- `primary_color` - (Optional) Color of buttons and links, as a hex value like `#635BFF`.
- `page_background_color` - (Optional) Background color of the login pages, as a hex value like `#F5F5F5`.

URLs must be publicly reachable HTTPS addresses.
DESCRIPTION
  type = object({
    friendly_name         = optional(string)
    picture_url           = optional(string)
    logo_url              = optional(string)
    favicon_url           = optional(string)
    primary_color         = optional(string)
    page_background_color = optional(string)
  })
  default = {}

  validation {
    condition = alltrue([
      for url in [var.auth0_branding.picture_url, var.auth0_branding.logo_url, var.auth0_branding.favicon_url] :
      url == null ? true : startswith(url, "https://")
    ])
    error_message = "auth0_branding URLs must start with https://."
  }

  validation {
    condition = alltrue([
      for color in [var.auth0_branding.primary_color, var.auth0_branding.page_background_color] :
      color == null || can(regex("^#[0-9A-Fa-f]{6}$", color))
    ])
    error_message = "auth0_branding colors must be hex values like #635BFF."
  }
}
