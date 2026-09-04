data "google_project" "project" {
}

resource "google_project_service" "playdeveloper_api" {
  project = data.google_project.project.project_id
  service = "androidpublisher.googleapis.com"
}

resource "google_project_service" "iam_api" {
  project = data.google_project.project.project_id
  service = "iam.googleapis.com"
}

resource "google_project_service" "iamcredentials_api" {
  project = data.google_project.project.project_id
  service = "iamcredentials.googleapis.com"
}

resource "google_iam_workload_identity_pool" "github" {
  project                   = data.google_project.project.project_id
  workload_identity_pool_id = "github-actions"
  display_name              = "GitHub Actions"
  description               = "Workload Identity Pool for GitHub Actions"

  depends_on = [
    google_project_service.iam_api,
    google_project_service.iamcredentials_api
  ]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = data.google_project.project.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"
  display_name                       = "GitHub Actions OIDC"
  description                        = "OIDC provider for GitHub Actions"

  attribute_mapping = {
    "google.subject"  = "assertion.sub"
    "attribute.actor" = "assertion.actor"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  attribute_condition = "assertion.repository_owner_id == '${var.github_org_id}'"
}

resource "google_service_account" "github_actions" {
  for_each = var.android_apps

  project      = data.google_project.project.project_id
  account_id   = substr(replace("github-${each.key}", "/", "-"), 0, 30)
  display_name = "GitHub Actions Workload Identity Federation for ${each.key}"

  depends_on = [
    google_iam_workload_identity_pool.github
  ]
}

resource "google_service_account_iam_member" "github_actions_wif_pr" {
  for_each = var.android_apps

  service_account_id = google_service_account.github_actions[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/subject/${each.value.gh_oidc_subject}:environment:pr"
}

resource "google_service_account_iam_member" "github_actions_wif_main" {
  for_each = var.android_apps

  service_account_id = google_service_account.github_actions[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/subject/${each.value.gh_oidc_subject}:environment:main"
}

resource "google_service_account_iam_member" "github_actions_wif_release" {
  for_each = var.android_apps

  service_account_id = google_service_account.github_actions[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/subject/${each.value.gh_oidc_subject}:environment:release"
}

resource "googleplay_user" "github_actions" {
  for_each = var.android_apps

  email = google_service_account.github_actions[each.key].email

  global_permissions = [
    "CAN_VIEW_NON_FINANCIAL_DATA_GLOBAL"
  ]
}

resource "googleplay_app_iam" "github_actions" {
  for_each = var.android_apps

  app_id  = each.value.android_app_id
  user_id = googleplay_user.github_actions[each.key].email

  permissions = [
    "CAN_MANAGE_PERMISSIONS",
    "CAN_VIEW_FINANCIAL_DATA"
  ]
}
