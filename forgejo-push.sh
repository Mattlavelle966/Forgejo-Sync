#!/usr/bin/env bash

#set -e



source ./config.sh
source ./shTools/sync_issues.sh
#source ./shTools/sync_PRs.sh

CURRENT_DIR=$(pwd)

#result collectors 
failed_repos=()



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
mapfile -t repositories < <(python3 "$CURRENT_DIR/pyTools/json_array_to_lines.py" "$CURRENT_DIR/repolist.json")

for repo in "${repositories[@]}"; do
  echo "$repo"
done
echo "repo list loaded"

echo "--------------------------------------------------"

#main clone loop
for repo in "${repositories[@]}"; do
  navToSyncDir


  repo_name="${repo##*/}"

  echo "---------------------------------------------------"
  echo "Attempting clone of $repo"
  clone_url="https://x-access-token:${PRODUCER_DESTINATION_TOKEN}@${PRODUCER_DESTINATION_DOMAIN}/${FORGEUSER}/${repo_name}.git"
  if git clone "$clone_url"; then
    echo "clone of $repo succeeded"
  else
    echo "clone of $repo failed"

    failed_repos+=("$repo_name")
    continue  
  fi

  echo "Successfull clone of $repo"
  echo "Navigating to repo"
  
  echo "--------------------------------------------------"
  if cd "$repo_name"; then
    echo "Nav to repo $repo_name succeeded"
  else
    echo "Nav to repo failed for $repo_name"
    failed_repos+=("$repo_name")
    continue  
  fi


  echo "-------------------------------------------------"
  echo "Pushing current branch: $(git branch --show-current)"
  echo "Attempting a push of $repo"
  
  remote_url="https://${FORGEUSER}:${CONSUMER_DESTINATION_TOKEN}@${CONSUMER_DESTINATION_DOMAIN}/${FORGEUSER}/${repo_name}.git"
  if git push --mirror "$remote_url"; then
    echo "Pushing $repo to $remote_url has succeeded"
  else
    echo "Pushing $repo to $remote_url has Failed"

    failed_repos+=("$repo_name")
    continue  
  fi
  
  consumer_repo_url="https://${CONSUMER_DESTINATION_DOMAIN}/${FORGEUSER}/${repo_name}"
  dir=$(pwd)
  echo "$dir"
  echo "Attempting Sync $repo issues with $CONSUMER_DESTINATION_DOMAIN"
  if python3 "$CURRENT_DIR/pyTools/sync_issues.py" "$repo" "$consumer_repo_url"; then
    echo "issue Sync executed Successfully"
  else 
    echo "issue Sync Failed"
  fi

 # for a later release  
 # echo "Attempting to Sync $repo pull requests with $CONSUMER_DESTINATION_DOMAIN" 
 # if sync_pulls "$repo" "$consumer_repo_url"; then
 #   echo "pull requests Sync Successfull"
 # else 
 #   echo "pull requests Sync Failed"
 # fi

  

  echo "------------------------------------------------"
  navToSyncDir

  repo_path="${CURRENT_DIR}/Sync/${repo_name}"
  if [[ -d "$repo_path" && "$repo_path" == "$CURRENT_DIR/Sync/"* ]]; then
    rm -rf "$repo_path"
  else
    echo "Refusing to delete unexpected path: $repo_path"
  fi
 
done
echo "--------------------------------------------------"
echo "Failed Repos:"
for repo in "${failed_repos[@]}"; do
  echo "Repositorie Failed to Sync:{${repo}}"
done




