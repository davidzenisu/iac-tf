terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
    googleplay = {
      source  = "Oliver-Binns/googleplay"
      version = "~> 0.6"
    }
    auth0 = {
      source  = "auth0/auth0"
      version = "~> 1.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    supabase = {
      source  = "supabase/supabase"
      version = "~> 1.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.14"
    }
  }
  backend "azurerm" {}
}
