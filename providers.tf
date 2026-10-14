provider "azurerm" {
  features {}
}

# Authenticates with the same ARM_* OIDC settings as azurerm
provider "azuread" {}

provider "cloudflare" {
}

provider "googleplay" {
  developer_id = var.play_store_developer_id
}

provider "auth0" {}

provider "supabase" {}
