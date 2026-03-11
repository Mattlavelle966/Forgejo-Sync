#!/usr/bin/env bash

set -euo pipefail

source ./config.sh

CURRENT_PATH=$(pwd)


sync_issues() {

  local producer_repo_url="$1"
  local consumer_repo_url="$2"

  local github_path="${producer_repo_url#https://github.com/}"
  github_path="${github_path%/}"

  local forgejo_base="https://dropadox.sytes.net/net-760"
  local forgejo_path="${consumer_repo_url#${forgejo_base}/}"
  forgejo_path="${forgejo_path%/}"

  local github_issues_url="https://api.github.com/repos/${github_path}/issues?state=all&per_page=100"
  local forgejo_issues_url="${forgejo_base}/api/v1/repos/${forgejo_path}/issues"

  curl -s \
    -H "Authorization: Bearer ${PRODUCER_DESTINATION_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "$github_issues_url" \
  | python3 "$CURRENT_PATH/pyTools/json_lines.py" title body state \
  | while IFS= read -r issue_json
  do
    create_response="$(
      curl -s -X POST \
        -H "Authorization: token ${CONSUMER_DESTINATION_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "$issue_json" \
        "$forgejo_issues_url"
    )"

    issue_state="$(printf '%s' "$issue_json" | python3 "$CURRENT_PATH/pyTools/json_finder.py" state)"
    issue_number="$(printf '%s' "$create_response" | python3 "$CURRENT_PATH/pyTools/json_finder.py"  number)"

    echo "created issue #$issue_number with state=$issue_state"

    if [[ "$issue_state" == "closed" ]]; then
      curl -s -X PATCH \
        -H "Authorization: token ${CONSUMER_DESTINATION_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{"state":"closed"}' \
        "${forgejo_issues_url}/${issue_number}"

      echo "closed issue #$issue_number"
    fi

    printf '\n'
  done
}


# call like this 

#sync_issues \
#"https://github.com/Mattlavelle966/Playwright-Domain-Specific-Lang" \
#"https://dropadox.sytes.net/net-760/MattLavelle966/Playwright-Domain-Specific-Lang"
