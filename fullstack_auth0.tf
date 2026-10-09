locals {
  fullstack_auth_enabled = anytrue([
    for app in values(var.fullstack_apps) : app.auth
  ])
}

data "auth0_tenant" "fullstack" {
  count = local.fullstack_auth_enabled ? 1 : 0
}

resource "auth0_role" "user" {
  count = local.fullstack_auth_enabled ? 1 : 0

  name        = "user"
  description = "Standard role assigned to newly registered users."
}

resource "auth0_client" "signup_role_assignment" {
  count = local.fullstack_auth_enabled ? 1 : 0

  name     = "Signup role assignment"
  app_type = "non_interactive"

  jwt_configuration {
    alg = "RS256"
  }
}

resource "auth0_client_credentials" "signup_role_assignment" {
  count = local.fullstack_auth_enabled ? 1 : 0

  client_id             = auth0_client.signup_role_assignment[0].id
  authentication_method = "client_secret_basic"
}

resource "auth0_client_grant" "signup_role_assignment" {
  count = local.fullstack_auth_enabled ? 1 : 0

  client_id = auth0_client.signup_role_assignment[0].id
  audience  = "https://${data.auth0_tenant.fullstack[0].domain}/api/v2/"
  scopes    = ["update:users"]
}

resource "auth0_action" "assign_user_role" {
  count = local.fullstack_auth_enabled ? 1 : 0

  name    = "Assign default user role"
  runtime = "node22"
  deploy  = true
  code    = <<-JAVASCRIPT
    exports.onExecutePostUserRegistration = async (event, api) => {
      const ManagementClient = require('auth0').ManagementClient;

      const management = new ManagementClient({
          domain: event.secrets.AUTH0_DOMAIN,
          clientId: event.secrets.M2M_CLIENT_ID,
          clientSecret: event.secrets.M2M_CLIENT_SECRET,
      });

      const params =  { id : event.user.user_id};
      const data = { "roles" : [event.secrets.USER_ROLE_ID]};

      try {
        const res = await management.assignRolestoUser(params, data)
      } catch (e) {
        console.log(e)
        // Handle error
      }
    };
  JAVASCRIPT

  supported_triggers {
    id      = "post-user-registration"
    version = "v2"
  }

  secrets {
    name  = "AUTH0_DOMAIN"
    value = data.auth0_tenant.fullstack[0].domain
  }

  secrets {
    name  = "M2M_CLIENT_ID"
    value = auth0_client.signup_role_assignment[0].client_id
  }

  secrets {
    name  = "M2M_CLIENT_SECRET"
    value = auth0_client_credentials.signup_role_assignment[0].client_secret
  }

  secrets {
    name  = "USER_ROLE_ID"
    value = auth0_role.user[0].id
  }
}

resource "auth0_trigger_action" "assign_user_role" {
  count = local.fullstack_auth_enabled ? 1 : 0

  trigger   = "post-user-registration"
  action_id = auth0_action.assign_user_role[0].id
}
