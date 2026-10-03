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
    custom_domain            = optional(string)
    frontend                 = optional(bool, true)
    backend                  = optional(bool, true)
    storage                  = optional(bool, true)
    database                 = optional(bool, true)
    auth                     = optional(bool, true)
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
      (!app.auth || app.frontend) &&
      (!app.database || app.supabase_organization_id != null)
    ])
    error_message = "Storage requires backend=true, auth requires frontend=true, and database=true requires supabase_organization_id."
  }

  validation {
    condition = (
      var.zone_name != null ||
      alltrue([
        for app in values(var.fullstack_apps) :
        !app.frontend || app.custom_domain == null
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
