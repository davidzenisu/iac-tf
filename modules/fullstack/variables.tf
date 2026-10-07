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
    supabase_organization_id = optional(string)
    supabase_region          = optional(string, "eu-west-1")
  })
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

