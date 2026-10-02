# Local Bootstrap

This directory provisions the GitHub Actions identities and repository secrets previously created by scripts. It uses a separate local Terraform state; run it from a trusted machine with the Azure, Google Cloud, GitHub, and Terraform CLIs installed.

## Setup

1. Authenticate with an Azure account that can create managed identities and assign roles in the target subscription, a Google account with project IAM administration permissions, and a GitHub account with repository administration permissions. The bootstrap script runs `az login`, `gcloud auth login`, `gcloud auth application-default login`, and `gh auth login` only when the corresponding CLI needs authentication.
2. Copy `terraform.tfvars.example` to `terraform.tfvars` and fill in the existing Azure state resource group/storage account, a unique Google Cloud project ID and display name, billing account ID, and Google Play developer account ID. Terraform creates the project, service account, and Play Console access.
3. Create a Cloudflare API token with `Zone:Read` and `DNS:Edit` permissions limited to the zone(s) managed by this repository. Put it in `cloudflare_api_token` in `terraform.tfvars`. This token is only passed to Terraform to create/update the repository's GitHub Actions secret; Cloudflare authentication in the normal deployment workflow continues to use that secret.
4. Run `bash .bootstrap/bootstrap.sh` from the repository root. The script derives the GitHub owner, repository, and immutable repository ID from `gh`, uses the active Azure and Google CLI credentials, then runs Terraform init and apply.

The `.bootstrap/terraform.tfvars` file is ignored by Git. Treat `.bootstrap/terraform.tfstate` and local backups as sensitive too, because state may contain secret values. Do not commit or share either file. The bootstrap state is local and should be backed up securely if you need to manage these resources from another machine.

If the old scripts have already created any of these resources, import those resources into the bootstrap state before applying. Terraform does not automatically adopt existing Azure identities/role assignments, Google projects/IAM resources, or GitHub secrets, and attempting to create duplicate resources will fail or replace secret values. For an existing Google project, initialize the bootstrap root and import it with `terraform -chdir=.bootstrap import -var-file=terraform.tfvars google_project.bootstrap PROJECT_ID`; import other existing resources using their provider-specific import IDs before running the bootstrap script.

Terraform grants the GitHub Actions Google service account the same project-wide `roles/owner` access used by the previous setup script. Review that permission against your project requirements before applying.