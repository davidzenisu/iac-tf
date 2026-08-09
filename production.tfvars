zone_name = "zeni-su.com"

dns_records = {
  "david" = {
    name    = "david"
    content = "davidzenisu.github.io"
    type    = "CNAME"
  }
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
}

static_web_apps = {
  "events" = {
    name                = "stapp-zenisu-events"
    resource_group_name = "rg-zenisu-events"
    location            = "westeurope"
    source_repo         = "davidzenisu/page-form-collections"
    custom_domain       = "events"
  }
  "radio-guesser" = {
    name                = "stapp-zenisu-radio-guesser"
    resource_group_name = "rg-zenisu-radio-guesser"
    location            = "westeurope"
    source_repo         = "davidzenisu/game-radio-guesser"
    custom_domain       = "radio"
  }
  "gods-pet" = {
    name                = "stapp-zenisu-gods-pet"
    resource_group_name = "rg-zenisu-gods-pet"
    location            = "westeurope"
    source_repo         = "davidzenisu/game-gods-pet"
    custom_domain       = "gods"
  }
}

play_store_developer_id = "6400912963140305270"

android_apps = {
  "game-gods-pet" = {
    gh_oidc_subject = "repo:davidzenisu@32648667/game-gods-pet@1014907206"
    android_app_id  = "com.luvdav.godspet"
  }
}
