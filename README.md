## Overview

This script automates the synchronization of GitHub repositories to a Forgejo server. It essentially creates an exact mirror of a specific Github users repositories, including every branch and all major pieces of meta-data(issues, Pr's, comments). The intended use case is so you can use Github as your primary remote suite and use Forgejo as a backup suite should you have an issue with Github like an account loss or ban of some kind. This way if you loose your account, as long as you have been regularly syncing your Github account, you will always have a backup of every repository, branch, pull, Issue and comment. Forgejo-Sync can simply be run whenever you want to back-up all of your users Github repositories.   

### Function

The script uses 2 bearer tokens and starts by fetching a users repository list, which generates a list of that users private and public repositories in JSON, it then clones them from GitHub into `./Sync`, constructs a Forgejo remote, and pushes each repository to the Forgejo server. Additionally, it syncs issues, pull requests, branches and all comments including comments under open and closed Pr's and issues.

### Dependencies

- Bash
- Git
- Python
- Bearer Tokens

### Configuration

Create a `config.sh` file with the following template, replacing the placeholder values with your actual credentials:

```bash
#!/usr/bin/env bash

export PRODUCER_FORGEUSER="MattLavelle966"  # GitHub username or organization
export CONSUMER_FORGEUSER="MattLavelle966"  # Forgejo username
export CONSUMER_DESTINATION_TOKEN="your_consumer_token"  # Token for accessing Forgejo
export CONSUMER_DESTINATION_DOMAIN="your_consumer_domain"  # Domain for Forgejo
export PRODUCER_DESTINATION_TOKEN="your_producer_token"  # Token for accessing GitHub
export PRODUCER_DESTINATION_DOMAIN="github.com"  # Domain for GitHub
```

### Running the Script

1. Ensure you have the necessary dependencies installed.
2. Run the script:

```bash
./forgejo-push.sh
```

The script is fully automated, just wait for it to finish, depending on how large and how many repositories you have this can take a variable amount of time.

### Additional Notes

- Python handles all Rest-API syncing (Pr's, Issues, Comments, User's repository list).
- Bash handles the cloning of each repository, the pushing of each branch to the Forgejo's remote repository and the calling of each python tool for syncing meta-data. 

### Known issues

- When meta-data is synced, the comments original contributors cant be maintained as there is no guarantee that the same user exists in the DB, so we insert a comment at the top of each synced comment with the original contributors Github username.
- Comment date and time meta-data are lost during a repositories first sync, since all pushes go through your bearer token and all Pr's, Comments and Issues have to be created fresh, too stop this loss of data we insert text snippets that come from Githubs meta-data during the sync process. 
- If a Pr's is opened on Github, and a sync is run, it will sync correctly, but after that Pr is closed on Github and another sync is run, the Pr will still be open in Forgejo, this is purley cosmetic the merge and code state will be synced correctly, the Pr will just remain open. 

### Planned Enhancements

- Optimize syncing:
  - before syncing a repository, call the Forgejo Rest-API to see if that repository is already synced,  
- More Meta-data
  - Tag Meta-data
  -  Markdown formatting for synced Comments, Pr's and Issues 
