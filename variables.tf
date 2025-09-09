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
    name                = string
    resource_group_name = string
    location            = string
    custom_domain       = optional(string)
  }))
  default = {}
}
