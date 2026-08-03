provider "azurerm" {
  features {}
}

provider "cloudflare" {
}

provider "googleplay" {
  service_account_json_base64 = filebase64(pathexpand("~/service-account.json"))
  developer_id                = var.play_store_developer_id
}
