zone_name = "zeni-su.com"

dns_records = {
  "github" = {
    name    = "github"
    content = "davidzenisu.github.io"
    type    = "CNAME"
  }
  "grades" = {
    name    = "grades"
    content = "zealous-forest-0c694b103.3.azurestaticapps.net"
    type    = "CNAME"
  }
  "bluesky" = {
    name    = "_atproto.david"
    content = "did=did:plc:33zzvayo7qynpcba2varefbq"
    type    = "TXT"
  }
  "easyname" = {
    name    = "easyname4a8eec77f5b90b72"
    content = "www.easyname.com"
    type    = "CNAME"
  }
}

static_web_apps = {
  "portfolio" = {
    name                 = "stapp-zenisu-portfolio"
    resource_group_name  = "rg-zenisu-portfolio"
    location             = "westeurope"
    github_subject_claim = "repo:davidzenisu@32648667/page-portfolio-littlelink@1338235825"
    custom_domain        = "david"
  }
  "events" = {
    name                 = "stapp-zenisu-events"
    resource_group_name  = "rg-zenisu-events"
    location             = "westeurope"
    github_subject_claim = "repo:davidzenisu@32648667/page-form-collections@1039886512"
    custom_domain        = "events"
  }
  "radio-guesser" = {
    name                 = "stapp-zenisu-radio-guesser"
    resource_group_name  = "rg-zenisu-radio-guesser"
    location             = "westeurope"
    github_subject_claim = "repo:davidzenisu@32648667/game-radio-guesser@1086371762"
    custom_domain        = "radio"
  }
  "gods-pet" = {
    name                 = "stapp-zenisu-gods-pet"
    resource_group_name  = "rg-zenisu-gods-pet"
    location             = "westeurope"
    github_subject_claim = "repo:davidzenisu@32648667/game-gods-pet@1014907206"
    custom_domain        = "gods"
  }
}

github_org_id = "32648667"

play_store_developer_id = "6400912963140305270"

android_apps = {
  "game-gods-pet" = {
    gh_oidc_subject = "repo:davidzenisu@32648667/game-gods-pet@1014907206"
    android_app_id  = "com.luvdav.godspet"
  }
}

# Placeholder branding values; replace them before merging
auth0_branding = {
  friendly_name         = "Ovid Games"
  logo_url              = "https://david.zeni-su.com/images/avatar.png"
  favicon_url           = "https://david.zeni-su.com/images/avatar.png"
  primary_color         = "#635BFF"
  page_background_color = "#F5F5F5"
}

fullstack_apps = {
  "drawing-duel" = {
    project_name             = "drawing-duel"
    location                 = "westeurope"
    github_subject_claim     = "repo:davidzenisu@32648667/game-drawing-duel@1361817871"
    function_runtime_name    = "python"
    function_runtime_version = "3.14"
    custom_domain            = "drawing"
    display_name             = "Drawing Duel"
    supabase_organization_id = "htvllqfeppqjdwgdbkuj" #Slug only
    auth0_permissions = {
      "edit:content"   = { description = "Access the prompt and title pregenerated contents" }
      "manage:servers" = {}
    }
  }
}

auth0_google_connection_id = "con_WeZqT0YKtzkZ8MOq"
