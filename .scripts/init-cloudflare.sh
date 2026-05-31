#!/usr/bin/env bash
set -euo pipefail

CLOUDFLARE_SECRET_KEY=CLOUDFLARE_API_TOKEN
red='\033[0;31m'
green='\033[0;32m'
nc='\033[0m' # No Color

if gh auth status >/dev/null 2>&1; then
  echo "Already logged into GitHub CLI."
else
  echo "GitHub CLI login required."
  gh auth login
fi

read -p "Enter your Cloudflare API key: " CLOUDFLARE_SECRET_INPUT
read -p "Are you want to set the Cloudflare secret for your current repo? (yes/no) " yn
case "$yn" in
  yes ) echo "Ok, setting Cloudflare secret...";;
  no ) echo "Exiting..."; exit 1;;
  * ) echo "Invalid response. Exiting..."; exit 1;;
 esac

echo "Setting Cloudflare secret..."
gh secret set "$CLOUDFLARE_SECRET_KEY" --body "$CLOUDFLARE_SECRET_INPUT"

echo -e "${green}✓${nc} Cloudflare secret set successfully!"
