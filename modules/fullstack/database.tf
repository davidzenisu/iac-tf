resource "random_password" "this" {
  for_each = local.database_apps

  length  = 32
  special = true
}

resource "supabase_project" "this" {
  for_each = local.database_apps

  organization_id   = each.value.supabase_organization_id
  name              = each.value.project_name
  database_password = random_password.this[each.key].result
  region            = each.value.supabase_region
}

