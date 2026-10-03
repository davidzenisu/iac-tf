provider "azurerm" {
  features {}
  use_cli = true
}

provider "google" {
  project = var.gcp_project_id
}

provider "googleplay" {
  developer_id = var.play_store_developer_id
}

provider "github" {
  owner = var.github_owner
}
