resource "random_password" "this" {
  count = var.fullstack_app.database ? 1 : 0

  length  = 16
  special = false
}

resource "supabase_project" "this" {
  count = var.fullstack_app.database ? 1 : 0

  organization_id   = var.fullstack_app.supabase_organization_id
  name              = var.fullstack_app.project_name
  database_password = random_password.this[0].result
  region            = var.fullstack_app.supabase_region
}

data "supabase_pooler" "this" {
  count = var.fullstack_app.database ? 1 : 0

  project_ref = supabase_project.this[0].id
}

