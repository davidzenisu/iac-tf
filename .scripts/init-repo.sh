#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<EOF
Usage: $(basename "$0") [azure] [cloudflare] [all]

Options:
  azure        Run only Azure setup
  cloudflare   Run only Cloudflare setup
  all          Run Azure and Cloudflare setup in order
  help         Show this message

Examples:
  ./init-repo.sh azure
  ./init-repo.sh cloudflare
  ./init-repo.sh all
  ./init-repo.sh azure cloudflare
EOF
}

if [ $# -eq 0 ]; then
  usage
  exit 1
fi

run_azure=false
run_cloudflare=false

for arg in "$@"; do
  case "$arg" in
    azure|--azure)
      run_azure=true
      ;;
    cloudflare|--cloudflare)
      run_cloudflare=true
      ;;
    all|--all)
      run_azure=true
      run_cloudflare=true
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

if [ "$run_azure" != true ] && [ "$run_cloudflare" != true ]; then
  usage
  exit 1
fi

if [ "$run_azure" = true ]; then
  bash "$SCRIPT_DIR/init-azure.sh"
fi

if [ "$run_cloudflare" = true ]; then
  bash "$SCRIPT_DIR/init-cloudflare.sh"
fi
