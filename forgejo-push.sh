#!/usr/bin/env bash

#set -e



source ./config.sh

echo "Syncing $CONSUMER_FORGEUSER remote $CONSUMER_DESTINATION_DOMAIN with $PRODUCER_DESTINATION_DOMAIN"



echo "Fetching $CONSUMER_FORGEUSER repo list for Sync"

if ./shTools/fetch_repos.sh; then
  echo "Fetch executed"
else
  echo "Fetch failed"
  exit 1
fi

echo "Fetch Complete"
echo -e "\e[35m----------------------------------------\e[0m"


CURRENT_DIR=$(pwd)

#result collectors 
failed_repos=()



navToSyncDir(){
  echo "Navigating to Sync dir"
  if cd "$CURRENT_DIR/Sync/"; then
    echo "Nav to Sync Dir has Succeded"
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
 
echo -e "\e[35m----------------------------------------\e[0m"
#loading in repo list
echo "starting Sync with $PRODUCER_FORGEUSER"
mapfile -t repositories < <(python3 "$CURRENT_DIR/pyTools/json_array_to_lines.py" "$CURRENT_DIR/repo_names.json")

for repo in "${repositories[@]}"; do
  echo "$repo"
done
echo "repo list loaded"
 
echo -e "\e[35m----------------------------------------\e[0m"

#main clone loop
for repo in "${repositories[@]}"; do
  navToSyncDir


  repo_name="${repo##*/}"
 
 echo -e "\e[35m----------------------------------------\e[0m"
  echo "Attempting clone of $repo"
  clone_url="https://x-access-token:${PRODUCER_DESTINATION_TOKEN}@${PRODUCER_DESTINATION_DOMAIN}/${PRODUCER_FORGEUSER}/${repo_name}.git"
  if git clone "$clone_url"; then
    echo "clone of $repo succeeded"
  else
    echo "clone of $repo failed"

    failed_repos+=("$repo_name")
    continue  
  fi

  echo "Successfull clone of $repo"
  echo "Navigating to repo"
   
 echo -e "\e[35m----------------------------------------\e[0m"
  if cd -- "$repo_name"; then
    echo "Nav to repo $repo_name succeeded"
  else
    echo "Nav to repo failed for $repo_name"
    failed_repos+=("$repo_name")
    continue  
  fi

 
 echo -e "\e[35m----------------------------------------\e[0m"
  echo "Pushing current branch: $(git branch --show-current)"
  echo "Attempting a push of $repo"
  
  remote_url="https://${CONSUMER_FORGEUSER}:${CONSUMER_DESTINATION_TOKEN}@${CONSUMER_DESTINATION_DOMAIN}/${CONSUMER_FORGEUSER}/${repo_name}.git"
  #send every branch so prs can import
  while IFS= read -r branch; do
    #skipping origin
    [[ "$branch" == "origin" ]] && continue
    #skipping origin/HEAD
    [[ "$branch" == "origin/HEAD" ]] && continue

    short_branch="${branch#origin/}"
    git push "$remote_url" -- "refs/remotes/${branch}:refs/heads/${short_branch}"
  done < <(git for-each-ref --format='%(refname:short)' refs/remotes/origin)

  
  consumer_repo_url="https://${CONSUMER_DESTINATION_DOMAIN}/${CONSUMER_FORGEUSER}/${repo_name}"
  dir=$(pwd)
  echo "$dir"
  echo "Attempting Sync $repo issues with $CONSUMER_DESTINATION_DOMAIN"
  if python3 "$CURRENT_DIR/pyTools/sync_issues.py" "$repo" "$consumer_repo_url"; then
    echo "issue Sync executed Successfully"
  else 
    echo "issue Sync Failed"
  fi


  echo "Attempting to Sync $repo pull requests with $CONSUMER_DESTINATION_DOMAIN" 
  if python3 "$CURRENT_DIR/pyTools/sync_pulls.py" "$repo" "$consumer_repo_url"; then
    echo "pull requests Sync executed Successfully"
  else 
    echo "pull requests Sync Failed"
  fi

  
 
 echo -e "\e[35m----------------------------------------\e[0m"
  navToSyncDir

   
done
echo -e "\e[35m----------------------------------------\e[0m"
echo "Failed Repos:"
for repo in "${failed_repos[@]}"; do
  echo "Repositorie Failed to Sync:{${repo}}"
done

repo_path="${CURRENT_DIR}/Sync/"
if [[ -d "$repo_path" && "$repo_path" == "$CURRENT_DIR/Sync/"* ]]; then
  rm -rf "$repo_path"
else
  echo "Refusing to delete unexpected path: $repo_path"
fi





