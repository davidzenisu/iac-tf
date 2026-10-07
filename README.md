# iac-cloudflare
Repository to manage DNS entries in Cloudflare using IaC

## Getting started

To get started, [fork this repository](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/fork-a-repo).
Then, depending on your preferred setup, the following configuration has to be set:

### GitHub Secrets (GitHub Action workflows)

If you are using the provided GitHub Actions, make sure the following variables are set as secrets:

- *CLOUDFLARE_API_TOKEN*: Token to authenticate with the Cloudflare API. Should be considered highly sensitive. For more details see [here](https://developers.cloudflare.com/fundamentals/api/get-started/create-token/).

Provision the GitHub Actions identities and repository secrets locally with the Terraform configuration in `.bootstrap`:

```bash
bash .bootstrap/bootstrap.sh
```

See [.bootstrap/README.md](.bootstrap/README.md) for the required CLI access, local variables, and Cloudflare API token setup.

### Environment variables (local development)

Deploying through GitHub Actions does not require setting environment variables (this is done as part of the workflow).
*If this is the case, the next section can be skipped!*

Ensure the following environment variables are set.
If you are running deployments in an non-interactive scenario, consider using the configuration tools provided by your CI/CD platform (e.g. [Github secrets](https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions))

- *CLOUDFLARE_API_TOKEN*: Token to authenticate with the Cloudflare API. Should be considered highly sensitive. For more details see [here](https://developers.cloudflare.com/fundamentals/api/get-started/create-token/).

### tfvars

Finally, create a `variables.tfvars` file when working locally or bring in external configuration dynamically as part of your CD to securly configure the different DNS records.

## Sample

The following bash sample let's you test the initial setup (make sure to replace API key and zone name):

```bash
export CLOUDFLARE_API_TOKEN=XXXXXXXXXXXXXXXXXXXXXXX
terraform init
terraform plan -var='dns_records={test={name="test",content="test",type="TXT"}}' -var='zone_name=sample.com'
```

## Fullstack applications

Fullstack projects are configured through `fullstack_apps` and the local module in [`modules/fullstack/`](./modules/fullstack). The module is split by stack (`identity`, `key_vault`, `frontend`, `backend`, `storage`, `database`, and `auth`). Resource names are derived from each `project_name`; the map key is an arbitrary Terraform instance key. The GitHub Actions identity and its `main`/pull-request OIDC credentials are always created. All five feature switches default to `true`:

- `frontend` creates a Static Web App, its optional custom domain, and a Key Vault. The Key Vault is also created when `backend = true` so the Function App can access secrets.
- `backend` creates a Linux Function App, its user-assigned identity, and a Storage Account. When the frontend and its custom domain are configured, the Function App receives `FRONTEND_URL` set to that HTTPS URL.
- `storage` creates a private data container in that account (requires `backend = true`).
- `database` creates a Supabase project with a Terraform-generated database password.
- `auth` creates an Auth0 SPA client with callback/origin URLs for the frontend (requires `frontend = true`).

For example:

```hcl
zone_name = "example.com"

fullstack_apps = {
  storefront = {
    project_name             = "storefront"
    location                 = "westeurope"
    github_subject_claim     = "repo:example-org@123456/storefront@654321"
    custom_domain            = "shop"
    supabase_organization_id = "your-supabase-organization"
    supabase_region          = "eu-west-1"
  }
}
```

Set the provider credentials through `SUPABASE_ACCESS_TOKEN`, `AUTH0_DOMAIN`, `AUTH0_CLIENT_ID`, and `AUTH0_CLIENT_SECRET`. The root Terraform configuration outputs the GitHub OIDC client/tenant/subscription identifiers, Auth0 client IDs, and Supabase project IDs; the database password is kept in Terraform state and is not output.