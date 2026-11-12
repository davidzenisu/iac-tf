locals {
  auth0_tenant_branding_configured = anytrue([
    for value in [var.auth0_branding.friendly_name, var.auth0_branding.picture_url] : value != null
  ])
  auth0_login_branding_configured = anytrue([
    for value in [
      var.auth0_branding.logo_url,
      var.auth0_branding.favicon_url,
      var.auth0_branding.primary_color,
      var.auth0_branding.page_background_color,
    ] : value != null
  ])
  auth0_login_colors_configured = anytrue([
    for value in [var.auth0_branding.primary_color, var.auth0_branding.page_background_color] : value != null
  ])
}

# The tenant already exists; this resource only manages the settings below. Removing it from the
# configuration leaves the tenant untouched.
resource "auth0_tenant" "this" {
  count = local.auth0_tenant_branding_configured ? 1 : 0

  friendly_name = var.auth0_branding.friendly_name
  picture_url   = var.auth0_branding.picture_url
}

# Temporarily not managed: with the Auth0 custom domain in place (#65), Auth0 answers the branding
# API with "402 Payment Required" on the free plan, which fails every plan. Forgetting it (the
# branding itself stays in Auth0) lets the custom domain be removed; bring the resource back
# afterwards to manage the branding again.
removed {
  from = auth0_branding.this

  lifecycle {
    destroy = false
  }
}
