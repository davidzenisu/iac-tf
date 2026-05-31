#!/usr/bin/env bash
set -euo pipefail

GITHUB_TOKEN_CACHE="${GITHUB_TOKEN:-}"
export GITHUB_TOKEN=""

cleanup() {
  export GITHUB_TOKEN="$GITHUB_TOKEN_CACHE"
}
trap cleanup EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<EOF
Usage: $(basename "$0") [azure] [cloudflare] [gcp] [all]

Options:
  azure        Run only Azure setup
  cloudflare   Run only Cloudflare setup
  gcp          Run only GCP setup
  all          Run Azure, Cloudflare, and GCP setup in order
  help         Show this message

Examples:
  ./init-repo.sh azure
  ./init-repo.sh cloudflare
  ./init-repo.sh gcp
  ./init-repo.sh all
  ./init-repo.sh azure cloudflare gcp
EOF
}

if [ $# -eq 0 ]; then
  usage
  exit 1
fi

run_azure=false
run_cloudflare=false
run_gcp=false

for arg in "$@"; do
  case "$arg" in
    azure|--azure)
      run_azure=true
      ;;
    cloudflare|--cloudflare)
      run_cloudflare=true
      ;;
    gcp|--gcp)
      run_gcp=true
      ;;
    all|--all)
      run_azure=true
      run_cloudflare=true
      run_gcp=true
      ;;
    help|--help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $arg"
      usage
      exit 1
      ;;
  esac
 done

if [ "$run_azure" != true ] && [ "$run_cloudflare" != true ] && [ "$run_gcp" != true ]; then
  usage
  exit 1
fi

if [ "$run_azure" = true ]; then
  bash "$SCRIPT_DIR/init-azure.sh"
fi

if [ "$run_cloudflare" = true ]; then
  bash "$SCRIPT_DIR/init-cloudflare.sh"
fi

if [ "$run_gcp" = true ]; then
  bash "$SCRIPT_DIR/init-gcp.sh"
fi
