#!/usr/bin/env bash

set -Eeuo pipefail

readonly API_ROOT="https://androidpublisher.googleapis.com/androidpublisher/v3"
readonly ANDROID_PUBLISHER_SCOPE="https://www.googleapis.com/auth/androidpublisher"

red='\033[0;31m'
green='\033[0;32m'
nc='\033[0m'

log() {
  printf '[google-play] %s\n' "$*" >&2
}

info() {
  printf '%b[google-play] %s%b\n' "$green" "$*" "$nc" >&2
}

fail() {
  printf '%b[google-play] ERROR: %s%b\n' "$red" "$*" "$nc" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 ||
    fail "Required command not found: $1"
}

require_variable() {
  local variable_name="$1"

  [[ -n "${!variable_name:-}" ]] ||
    fail "Required environment variable is not set: ${variable_name}"
}

urlencode() {
  # jq encodes a string as a URI path component.
  jq -rn --arg value "$1" '$value | @uri'
}

response_body_file() {
  mktemp "${TMPDIR:-/tmp}/google-play-response.XXXXXX"
}

print_api_error() {
  local body_file="$1"

  if jq -e . "$body_file" >/dev/null 2>&1; then
    jq . "$body_file" >&2
  else
    cat "$body_file" >&2
  fi
}

get_access_token() {
  # An explicitly supplied token takes precedence.
  if [[ -n "${ACCESS_TOKEN:-}" ]]; then
    printf '%s' "$ACCESS_TOKEN"
    return
  fi

  # This uses Application Default Credentials. In GitHub Actions,
  # google-github-actions/auth can create the ADC credential file.
  gcloud auth print-access-token
}

api_request() {
  local method="$1"
  local url="$2"
  local output_file="$3"
  local payload="${4:-}"

  local -a curl_arguments=(
    --silent
    --show-error
    --request "$method"
    --output "$output_file"
    --write-out '%{http_code}'
    --header "Authorization: Bearer ${ACCESS_TOKEN}"
    --header 'Accept: application/json'
  )

  if [[ -n "$payload" ]]; then
    curl_arguments+=(
      --header 'Content-Type: application/json'
      --data "$payload"
    )
  fi

  curl "${curl_arguments[@]}" "$url"
}

is_success_status() {
  local status="$1"
  [[ "$status" =~ ^2[0-9][0-9]$ ]]
}

user_exists() {
  local page_token=""
  local body_file
  local status
  local url

  while true; do
    body_file="$(response_body_file)"

    url="${API_ROOT}/developers/${DEVELOPER_ID}/users?pageSize=100"

    if [[ -n "$page_token" ]]; then
      url+="&pageToken=$(urlencode "$page_token")"
    fi

    status="$(api_request GET "$url" "$body_file")"

    if ! is_success_status "$status"; then
      log "Could not list Google Play users. HTTP ${status}"
      print_api_error "$body_file"
      rm -f "$body_file"
      return 2
    fi

    if jq -e \
      --arg email "$SERVICE_ACCOUNT_EMAIL" \
      '.users // [] | any(.email == $email)' \
      "$body_file" >/dev/null; then
      rm -f "$body_file"
      return 0
    fi

    page_token="$(
      jq -r '.nextPageToken // empty' "$body_file"
    )"

    rm -f "$body_file"

    [[ -n "$page_token" ]] || return 1
  done
}

create_user() {
  local body_file
  local status
  local payload

  payload="$(
    jq -n \
      --arg email "$SERVICE_ACCOUNT_EMAIL" \
      --argjson permissions "$GLOBAL_PERMISSIONS_JSON" \
      '{
        email: $email,
        developerAccountPermissions: $permissions
      }'
  )"

  body_file="$(response_body_file)"

  status="$(
    api_request \
      POST \
      "${API_ROOT}/developers/${DEVELOPER_ID}/users" \
      "$body_file" \
      "$payload"
  )"

  if is_success_status "$status"; then
    log "Created Play Console user ${SERVICE_ACCOUNT_EMAIL}."
    rm -f "$body_file"
    return
  fi

  log "User creation returned HTTP ${status}; checking whether the user already exists."

  if user_exists; then
    log "Play Console user ${SERVICE_ACCOUNT_EMAIL} already exists."
    rm -f "$body_file"
    return
  fi

  log "Failed to create Play Console user. HTTP ${status}"
  print_api_error "$body_file"
  rm -f "$body_file"
  exit 1
}

upsert_app_grant() {
  local body_file
  local status
  local payload
  local encoded_email
  local encoded_package_name
  local user_resource
  local grant_resource
  local grant_url
  local create_url

  encoded_email="$(urlencode "$SERVICE_ACCOUNT_EMAIL")"
  encoded_package_name="$(urlencode "$PACKAGE_NAME")"

  user_resource="developers/${DEVELOPER_ID}/users/${SERVICE_ACCOUNT_EMAIL}"
  grant_resource="${user_resource}/grants/${PACKAGE_NAME}"

  grant_url="${API_ROOT}/developers/${DEVELOPER_ID}/users/${encoded_email}/grants/${encoded_package_name}"
  create_url="${API_ROOT}/developers/${DEVELOPER_ID}/users/${encoded_email}/grants"

  payload="$(
    jq -n \
      --arg name "$grant_resource" \
      --arg package_name "$PACKAGE_NAME" \
      --argjson permissions "$APP_PERMISSIONS_JSON" \
      '{
        name: $name,
        packageName: $package_name,
        appLevelPermissions: $permissions
      }'
  )"

  body_file="$(response_body_file)"

  status="$(
    api_request \
      PATCH \
      "${grant_url}?updateMask=appLevelPermissions" \
      "$body_file" \
      "$payload"
  )"

  if is_success_status "$status"; then
    log "Updated app grant for ${PACKAGE_NAME}."
    rm -f "$body_file"
    return
  fi

  if [[ "$status" != "404" ]]; then
    log "Failed to update app grant. HTTP ${status}"
    print_api_error "$body_file"
    rm -f "$body_file"
    exit 1
  fi

  rm -f "$body_file"
  body_file="$(response_body_file)"

  log "App grant does not exist; creating it."

  status="$(
    api_request \
      POST \
      "$create_url" \
      "$body_file" \
      "$payload"
  )"

  if is_success_status "$status"; then
    log "Created app grant for ${PACKAGE_NAME}."
    rm -f "$body_file"
    return
  fi

  # A concurrent execution may have created the grant between PATCH and POST.
  if [[ "$status" == "409" ]]; then
    log "Grant creation returned HTTP 409; retrying as an update."
    rm -f "$body_file"
    body_file="$(response_body_file)"

    status="$(
      api_request \
        PATCH \
        "${grant_url}?updateMask=appLevelPermissions" \
        "$body_file" \
        "$payload"
    )"

    if is_success_status "$status"; then
      log "Updated app grant after concurrent creation."
      rm -f "$body_file"
      return
    fi
  fi

  log "Failed to create app grant. HTTP ${status}"
  print_api_error "$body_file"
  rm -f "$body_file"
  exit 1
}

prompt_if_missing() {
  local variable_name="$1"
  local prompt="$2"
  local value="${!variable_name:-}"

  if [[ -n "$value" ]]; then
    return
  fi

  read -r -p "$prompt" value
  export "$variable_name=$value"
}

main() {
  require_command curl
  require_command jq
  require_command gcloud

  prompt_if_missing DEVELOPER_ID "Enter your Google Play developer ID: "
  prompt_if_missing SERVICE_ACCOUNT_EMAIL "Enter the Google service account email to grant access to: "
  prompt_if_missing PACKAGE_NAME "Enter the Android app package name: "

  # Account-level permissions required when initially creating the user.
  #
  # This is deliberately read-only, but it allows viewing non-financial
  # information across the developer account. Existing users created manually
  # with app-only access do not necessarily need this permission.
  GLOBAL_PERMISSIONS_JSON="$(
    printf '%s' \
      "${GLOBAL_PERMISSIONS_JSON:-[\"CAN_VIEW_NON_FINANCIAL_DATA_GLOBAL\"]}" |
      jq -c .
  )"

  # Default allows releases to testing tracks and production.
  APP_PERMISSIONS_JSON="$(
    printf '%s' \
      "${APP_PERMISSIONS_JSON:-[
        \"CAN_VIEW_NON_FINANCIAL_DATA\",
        \"CAN_MANAGE_TRACK_APKS\",
        \"CAN_MANAGE_PUBLIC_APKS\"
      ]}" |
      jq -c .
  )"

  ACCESS_TOKEN="$(get_access_token)"

  [[ -n "$ACCESS_TOKEN" ]] ||
    fail "Could not obtain a Google OAuth access token."

  create_user
  upsert_app_grant

  info "Configuration completed successfully."
  info "User: ${SERVICE_ACCOUNT_EMAIL}"
  info "App:  ${PACKAGE_NAME}"
}

main "$@"