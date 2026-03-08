#!/usr/bin/env bash

#set -e

FORGEUSER="MattLavelle966"
FORGEHOST="dropadox.sytes.net"
FORGEPORT="2222"

failed_repos=()


if cd ~/repos/forgejo-automation/Sync/; then
  echo "Automation Init Complete"
else
  echo "Automation Init Failed"
  exit 1
fi


echo "starting Sync with $FORGEUSER"
mapfile -t repositories < <(jq -r '.[]' ../repolist.json)




for repo in "${repositories[@]}"; do
  echo "$repo"
done
echo "repo list loaded"

for repo in "${repositories[@]}"; do
  ok=true

  repo_name="${repo##*/}"
  echo "$repo"

  echo "Attempting clone of $repo"
  if git clone "$repo"; then
    echo "clone of $repo succeeded"
  else
    ok=false
    echo "clone of $repo failed"
    failed_repos+=("$repo")
  fi
  
  if $ok; then 
    nav=true

    echo "Successfull clone of $repo"
    echo "Navigating to repo"
    
    if cd "$repo_name"; then
      echo "Nav to repo $repo_name succeeded"
    else
      echo "Nav to repo failed for $repo_name"
      nav=false
      failed_repos+=("$repo")
    fi

    if $nav; then 
      REPO_NAME=$(basename "$(git rev-parse --show-toplevel)")
      REMOTE_URL="ssh://git@${FORGEHOST}:${FORGEPORT}/${FORGEUSER}/${REPO_NAME}.git"
      success=true
      

      if ! git remote | grep -q "^forgejo$"; then
        git remote add forgejo "$REMOTE_URL"
        echo "added remote: $REMOTE_URL"
      else
        echo "remote 'forgejo' already exists"

      fi

      echo "Pushing current branch: $(git branch --show-current)"
      
      echo "Attempting a push of $repo to $REMOTE_URL"
      if GIT_SSH_COMMAND="ssh -i ~/.ssh/forgejo_automation_key -p ${FORGEPORT} -o IdentitiesOnly=yes" \
        git push --verbose -u forgejo HEAD; then
        echo "Pushing $repo to $REMOTE_URL has succeeded"
      else
        echo "Pushing $repo to $REMOTE_URL has Failed"
        failed_repos+=("$repo")
        success=false
      fi
      

      if $success; then
        echo "Forgejo is now Synced to Github:$repo -> $REMOTE_URL"
      else
        echo "Failed to Sync Forgejo to Github:$repo -> $REMOTE_URL"
      fi

    fi

    echo "returning to automation dir"
    if cd ~/repos/forgejo-automation/Sync/; then
      echo "Return to Sync Dir has Successfull"
    else
      echo "Return to Sync Dir has Failed"
    fi
  

  else
    echo "repo clone failed, skiping repo and moving onto next repo"
  fi
  
  ok=true
done

echo "Failed Repos"
for repo in "${failed_repos[@]}"; do
  echo "Repositorie Failed to Sync:{${repo}}"
done
