#!/usr/bin/env bash

set -euo pipefail

source ./config.sh

curl -s \
  -H "Authorization: Bearer ${PRODUCER_DESTINATION_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.${PRODUCER_DESTINATION_DOMAIN}/user/repos?per_page=100" \
  > repos.json

python3 ./pyTools/extract_repo_names.py repos.json repo_names.json
