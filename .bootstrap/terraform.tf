terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
    googleplay = {
      source  = "Oliver-Binns/googleplay"
      version = "~> 0.6"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.14"
    }
  }
}
