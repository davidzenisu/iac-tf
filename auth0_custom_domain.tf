locals {
  auth0_custom_domain_enabled = var.auth0_custom_domain != null && local.fullstack_auth_enabled

  # The domain the fullstack apps sign in through: the custom domain once Auth0 verified it, else
  # the tenant's. Referencing the verification makes Terraform switch the apps over only after it.
  auth0_login_domain = local.auth0_custom_domain_enabled ? (
    length(auth0_custom_domain_verification.this) > 0 ? auth0_custom_domain.this[0].domain : null
  ) : try(data.auth0_tenant.fullstack[0].domain, null)
}

# Login under our own domain (e.g. auth.zeni-su.com): Auth0's session cookie is then first-party
# for apps on the same zone, so browsers that block third-party cookies (Brave, Safari) don't
# break silent token renewal.
resource "auth0_custom_domain" "this" {
  count = local.auth0_custom_domain_enabled ? 1 : 0

  domain = "${var.auth0_custom_domain}.${var.zone_name}"
  type   = "auth0_managed_certs"
}

# DNS only: Auth0 manages the certificate and must see the CNAME, not Cloudflare's proxy.
resource "cloudflare_record" "auth0_custom_domain" {
  count = local.auth0_custom_domain_enabled ? 1 : 0

  zone_id = data.cloudflare_zone.this["default"].id
  name    = var.auth0_custom_domain
  type    = "CNAME"
  content = auth0_custom_domain.this[0].verification[0].methods[0].record
  proxied = false
}

resource "auth0_custom_domain_verification" "this" {
  count = local.auth0_custom_domain_enabled ? 1 : 0

  custom_domain_id = auth0_custom_domain.this[0].id

  # DNS can take a while to propagate; the provider retries until Auth0 sees the record.
  timeouts {
    create = "15m"
  }

  depends_on = [cloudflare_record.auth0_custom_domain]
}
