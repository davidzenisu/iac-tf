data "cloudflare_zone" "this" {
  for_each = var.zone_name != null ? { "default" : var.zone_name } : {}

  name = each.value
}

resource "cloudflare_record" "this" {
  for_each = var.dns_records

  zone_id = data.cloudflare_zone.this["default"].id
  name    = each.value.name
  content = each.value.content
  type    = each.value.type
  proxied = each.value.proxied
}
