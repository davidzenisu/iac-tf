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
    custom_domain       = "events.zeni-su.com"
  }
}
