provider "azurerm" {
  features {}
}

provider "cloudflare" {
}

provider "googleplay" {
  developer_id = var.play_store_developer_id
}
