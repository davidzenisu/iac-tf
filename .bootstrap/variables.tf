variable "github_owner" {
  description = "GitHub repository owner, populated from the authenticated GitHub CLI."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository name, populated from the authenticated GitHub CLI."
  type        = string
}

variable "github_repository_id" {
  description = "Immutable GitHub repository ID, populated from the authenticated GitHub CLI."
  type        = string
}

variable "azure_backend_resource_group" {
  description = "Existing Azure resource group containing the Terraform state storage account."
  type        = string
}

variable "azure_backend_storage_account" {
  description = "Globally unique name for the Azure storage account to create for the GitHub Actions Terraform backend."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.azure_backend_storage_account))
    error_message = "Azure storage account names must contain 3 to 24 lowercase letters or numbers."
  }
}

variable "azure_location" {
  description = "Azure region for the backend storage account and GitHub Actions identity."
  type        = string
}

variable "gcp_project_id" {
  description = "Google Cloud project ID to create or manage for GitHub Actions."
  type        = string
}

variable "gcp_project_name" {
  description = "Display name for the Google Cloud project."
  type        = string
}

variable "gcp_billing_account_id" {
  description = "Google Cloud billing account ID to associate with the project."
  type        = string
}

variable "gcp_service_account_name" {
  description = "Account ID for the GitHub Actions service account."
  type        = string
  default     = "github-actions-sa"
}

variable "play_store_developer_id" {
  description = "Google Play developer account ID."
  type        = string
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token stored as a GitHub Actions secret for the main Terraform workflow."
  type        = string
  sensitive   = true

  validation {
    condition     = length(trimspace(var.cloudflare_api_token)) > 0
    error_message = "Set cloudflare_api_token in .bootstrap/terraform.tfvars."
  }
}
