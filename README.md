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

Fullstack projects are configured through `fullstack_apps`. The root creates one instance of [`modules/fullstack/`](./modules/fullstack) per map entry and passes each project as a single object. The module is split by stack (`identity`, `key_vault`, `frontend`, `backend`, `storage`, `database`, and `auth`). Resource names are derived from each `project_name`; the map key identifies the module instance. The GitHub Actions identity and its `main`/pull-request OIDC credentials are always created. All five feature switches default to `true`:

- `frontend` creates a Static Web App, its optional custom domain, and a Key Vault. The Key Vault is also created when `backend = true` so the Function App can access secrets.
- `backend` creates a Linux Function App, its user-assigned identity, and a Storage Account. When the frontend and its custom domain are configured, the Function App receives `FRONTEND_URL` set to that HTTPS URL.
- `storage` creates a private data container in that account (requires `backend = true`).
- `database` creates a Supabase project with a Terraform-generated database password.
- `auth` creates an Auth0 SPA client and an API whose audience is the backend custom URL, with a `read:api` permission granted to users with the `user` role (requires `frontend = true`, `backend = true`, and `custom_domain`). New signups receive the `user` role through a tenant-wide Auth0 post-registration Action.

Google and GitHub social logins are deployed when their credentials are available. Before planning, the workflow loads the `auth0-<provider>-client-id` and `auth0-<provider>-client-secret` secrets from the bootstrap Key Vault (see [`.bootstrap/README.md`](./.bootstrap/README.md)) into the `auth0_<provider>_client_id`/`_client_secret` variables; secrets that don't exist leave their variables unset. A provider whose client id and secret are set is configured as an Auth0 connection; each fullstack app with `auth = true` receives the connection IDs through `auth0_connection_ids` and enables them for its own SPA and docs clients; providers without credentials are not deployed.

New Auth0 tenants come with a `google-oauth2` connection that uses Auth0's developer keys. Because connection names are unique, Terraform can't create its own Google connection while that one exists. Instead of deleting it (which would also delete every user who signed in with it), set its ID in `production.tfvars` so Terraform imports it on the next apply:

```hcl
auth0_google_connection_id = "con_XXXXXXXXXXXXXXXX"
```

The import only runs while the Google client id and secret are set, so the connection is part of the configuration. Once imported, the setting has no further effect and can stay or be removed. Terraform then manages the connection's credentials and scopes; apps enabled on it outside Terraform stay enabled. From then on, removing the Google credentials would make Terraform delete the connection, and with it every user who signed in with Google.

To find the connection ID in the [Auth0 Dashboard](https://manage.auth0.com/):

1. Go to **Authentication → Social** and open the **google-oauth2** connection.
2. Copy the ID from the browser's address bar. The URL ends in `/connections/social/con_XXXXXXXXXXXXXXXX/settings`; the `con_…` part is the connection ID.

Alternatively, with the Auth0 CLI (installed in the dev container): `auth0 api get "connections?strategy=google-oauth2&fields=id,name"`.

The Auth0 login page shows each app's `display_name` ("continue to <display_name>"); without it, the client name `spa-<project_name>` is shown. Tenant-wide branding of the login pages (tenant name, logo, favicon, and button and background colors) is set through `auth0_branding`; unset attributes keep the tenant's current values:

```hcl
auth0_branding = {
  friendly_name         = "Example"
  logo_url              = "https://example.com/logo.png"
  primary_color         = "#635BFF"
  page_background_color = "#F5F5F5"
}
```

Additional API permissions can be defined per app through `auth0_permissions`, a map from permission name to an object with an optional `description`. They are created on the app's API but not assigned to any role.

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
    auth0_permissions = {
      "write:orders" = { description = "Create and update orders." }
    }
  }
}
```

Set the provider credentials through `SUPABASE_ACCESS_TOKEN`, `AUTH0_DOMAIN`, `AUTH0_CLIENT_ID`, and `AUTH0_CLIENT_SECRET`. Each module instance exposes its GitHub OIDC client/tenant/subscription identifiers, Auth0 client ID and API audience, and Supabase project ID; the database password is kept in Terraform state and is not output. The Function App receives the Auth0 issuer, audience, and required scope as settings. Its handler must validate RS256 access tokens against those values and require `read:api`; Auth0 resource-server configuration does not enforce checks in application code by itself.