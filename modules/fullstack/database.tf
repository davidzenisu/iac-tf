resource "random_password" "this" {
  for_each = local.database_apps

  length  = 16
  special = false
}

resource "supabase_project" "this" {
  for_each = local.database_apps

  organization_id   = each.value.supabase_organization_id
  name              = each.value.project_name
  database_password = random_password.this[each.key].result
  region            = each.value.supabase_region
}

data "supabase_pooler" "this" {
  for_each = local.database_apps

  project_ref = supabase_project.this[each.key].id
}

