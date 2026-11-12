locals {
  auth0_tenant_branding_configured = anytrue([
    for value in [var.auth0_branding.friendly_name, var.auth0_branding.picture_url] : value != null
  ])
  auth0_login_branding_configured = anytrue([
    for value in [
      var.auth0_branding.logo_url,
      var.auth0_branding.favicon_url,
      var.auth0_branding.primary_color,
      var.auth0_branding.page_background_color,
    ] : value != null
  ])
  auth0_login_colors_configured = anytrue([
    for value in [var.auth0_branding.primary_color, var.auth0_branding.page_background_color] : value != null
  ])
}

# The tenant already exists; this resource only manages the settings below. Removing it from the
# configuration leaves the tenant untouched.
resource "auth0_tenant" "this" {
  count = local.auth0_tenant_branding_configured ? 1 : 0

  friendly_name = var.auth0_branding.friendly_name
  picture_url   = var.auth0_branding.picture_url
}

# The login page's logo and colors, as a Universal Login theme. Not through `auth0_branding`: with
# a custom domain (see auth0_custom_domain.tf), reading it also reads the custom page template, which
# the free plan answers with "402 Payment Required", failing every plan. Settings without a variable
# keep Auth0's defaults.
resource "auth0_branding_theme" "this" {
  count = local.auth0_login_branding_configured ? 1 : 0

  display_name = "Default"

  borders {
    button_border_radius = 3
    button_border_weight = 1
    buttons_style        = "rounded"
    input_border_radius  = 3
    input_border_weight  = 1
    inputs_style         = "rounded"
    show_widget_shadow   = true
    widget_border_weight = 0
    widget_corner_radius = 5
  }

  colors {
    body_text                 = "#1e212a"
    error                     = "#d03c38"
    header                    = "#1e212a"
    icons                     = "#65676e"
    input_background          = "#ffffff"
    input_border              = "#c9cace"
    input_filled_text         = "#000000"
    input_labels_placeholders = "#65676e"
    links_focused_components  = coalesce(var.auth0_branding.primary_color, "#635dff")
    primary_button            = coalesce(var.auth0_branding.primary_color, "#635dff")
    primary_button_label      = "#ffffff"
    secondary_button_border   = "#c9cace"
    secondary_button_label    = "#1e212a"
    success                   = "#13a688"
    widget_background         = "#ffffff"
    widget_border             = "#c9cace"
  }

  fonts {
    font_url            = ""
    links_style         = "normal"
    reference_text_size = 16

    body_text {
      bold = false
      size = 87.5
    }

    buttons_text {
      bold = false
      size = 100
    }

    input_labels {
      bold = false
      size = 100
    }

    links {
      bold = true
      size = 87.5
    }

    subtitle {
      bold = false
      size = 87.5
    }

    title {
      bold = false
      size = 150
    }
  }

  page_background {
    background_color     = coalesce(var.auth0_branding.page_background_color, "#000000")
    background_image_url = ""
    page_layout          = "center"
  }

  widget {
    header_text_alignment = "center"
    logo_height           = 52
    logo_position         = "center"
    logo_url              = var.auth0_branding.logo_url != null ? var.auth0_branding.logo_url : ""
    social_buttons_layout = "bottom"
  }
}

# Was the login branding; see the theme above. Forgotten, not deleted: Auth0 keeps its settings,
# among them the favicon, which a theme doesn't cover.
removed {
  from = auth0_branding.this

  lifecycle {
    destroy = false
  }
}
