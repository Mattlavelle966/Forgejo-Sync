#!/usr/bin/env bash

#set -e


read -p "Enter Your username for the Forgejo: " FORGEUSER

FORGEHOST="dropadox.sytes.net"
FORGEPORT="2222"

read -p "Enter in your Import target SSH-Key file (absolute): " SSH_KEY_IMPORT_REMOTE
read -p "Enter in your Export target SSH-Key file (absolute): " SSH_KEY_EXPORT_REMOTE
read -p "Enter the your JSON Array file path(absolute): " LISTPATH
CURRENT_DIR=$(pwd)

#result collectors 
failed_repos=()
succeded_repos=()


navToSyncDir(){
  echo "Navigating to Sync dir"
  if cd "$CURRENT_DIR/Sync/"; then
    echo "Nav to Sync Dir has Successfull"
    return 0
  else
    echo "Nav to Sync Dir has Failed"
    return 1
  fi
}



if navToSyncDir; then
  echo "Automation Init Complete"
else
  echo "Sync DIR not found attempting to make DIR.."
  if mkdir -p "$CURRENT_DIR/Sync/"; then
    if ! navToSyncDir; then
      echo "Failed to create DIR quiting program"
      exit 1
    fi
    echo "Sync Dir Created Automation Init Complete"
  else
    echo "Failed to create DIR quiting program"
    exit 1
  fi
fi

echo "--------------------------------------------------"
#loading in repo list
echo "starting Sync with $FORGEUSER"
mapfile -t repositories < <(jq -r '.[]' "$LISTPATH")
for repo in "${repositories[@]}"; do
  echo "$repo"
done
echo "repo list loaded"

echo "--------------------------------------------------"

#main clone loop
for repo in "${repositories[@]}"; do
  navToSyncDir
  success=true

  repo_name="${repo##*/}"
  repo_name="${repo_name%.git}"

  echo "--------------------------------------------------"
  echo "Attempting clone of $repo"
  if GIT_SSH_COMMAND="ssh -i \"${SSH_KEY_EXPORT_REMOTE}\" -o IdentitiesOnly=yes" \
    git clone "$repo"; then
    echo "clone of $repo succeeded"
  else
    echo "clone of $repo failed"
    success=false
    continue
  fi

  echo "Successfull clone of $repo"
  echo "Navigating to repo"
  
  echo "--------------------------------------------------"
  if cd "$repo_name"; then
    echo "Nav to repo $repo_name succeeded"
  else
    echo "Nav to repo failed for $repo_name"
    success=false
    continue
  fi

  REPO_NAME=$(basename "$(git rev-parse --show-toplevel)")
  REMOTE_URL="ssh://git@${FORGEHOST}:${FORGEPORT}/${FORGEUSER}/${REPO_NAME}.git"

  if ! git remote | grep -q "^forgejo$"; then
    git remote add forgejo "$REMOTE_URL"
    echo "added remote: $REMOTE_URL"
  else
    echo "remote 'forgejo' already exists"

  fi


  echo "--------------------------------------------------"
  echo "Pushing current branch: $(git branch --show-current)"
  echo "Attempting a push of $repo to $REMOTE_URL"

  if GIT_SSH_COMMAND="ssh -i \"${SSH_KEY_IMPORT_REMOTE}\" -p ${FORGEPORT} -o IdentitiesOnly=yes" \
    git push --verbose -u forgejo HEAD; then
    echo "Pushing $repo to $REMOTE_URL has succeeded"
  else
    echo "Pushing $repo to $REMOTE_URL has Failed"
    success=false
    continue
  fi

  navToSyncDir

  if $success; then
    succeded_repos+=("$repo")
  else
    failed_repos+=("$repo")
  fi
 
done
echo "--------------------------------------------------"
echo "Failed Repos:"
for repo in "${failed_repos[@]}"; do
  echo "Repositorie Failed to Sync:{${repo}}"
done




