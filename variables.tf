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
