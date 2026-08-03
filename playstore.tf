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
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = data.google_project.project.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"
  display_name                       = "GitHub Actions OIDC"
  description                        = "OIDC provider for GitHub Actions"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.repository_id"    = "assertion.repository_id"
    "attribute.actor"            = "assertion.actor"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  attribute_condition = length(var.android_apps) > 0 ? join([
    for repo in values(var.android_apps) : "attribute.repository_owner == '${var.github_owner}' && attribute.repository_id == '${repo.repo_id}'"
  ], " || ") : "attribute.repository_owner == '${var.github_owner}'"
}

resource "google_service_account" "github_actions" {
  for_each = var.android_apps

  project      = data.google_project.project.project_id
  account_id   = substr(replace("github-${each.value.repo_id}", "/", "-"), 0, 30)
  display_name = "GitHub Actions Workload Identity Federation for repo ${each.value.repo_id}"
}

resource "google_service_account_iam_member" "github_actions_wif" {
  for_each = var.android_apps

  service_account_id = google_service_account.github_actions[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${each.value.repo_id}"
}
