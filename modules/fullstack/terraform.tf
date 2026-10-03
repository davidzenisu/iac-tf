terraform {
  required_providers {
    auth0 = {
      source = "auth0/auth0"
    }
    azurerm = {
      source = "hashicorp/azurerm"
    }
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
    random = {
      source = "hashicorp/random"
    }
    supabase = {
      source = "supabase/supabase"
    }
    time = {
      source = "hashicorp/time"
    }
  }
}
