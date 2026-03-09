# Forgejo Repository Sync Script

## Purpose

This script clones repositories from an **export source** (where the data currently lives) and pushes them into an **import target** (where you want the repositories to end up).

It was written mainly to sync personal GitHub repositories into a Forgejo server.

Concept:

Export (source of data) -> Import (destination)

Example:

GitHub -> Forgejo

---

# Requirements

You need:

- `bash`
- `git`
- `jq`
- SSH access configured for both remotes

Install jq if needed:

`sudo pacman -S jq`

(or your distro equivalent)

---

# Repository List Format

The script expects a JSON array containing SSH repository URLs.

Example repolist.json
```
[
  "git@github.com:Mattlavelle966/reponame",
  "git@github.com:Mattlavelle966/reponame2",
  "git@github.com:Mattlavelle966/reponame3"
]
```
Notes:

- Use SSH URLs
- `.git` is optional suffix

---

# Running the Script

Run:

./forgejo-push.sh

The script will prompt for several values.

Example input:

```
Enter Your username for the Forgejo: MattLavelle966  
Enter in your Import target SSH-Key file (absolute): /home/matt/.ssh/forgejo_key  
Enter in your Export target SSH-Key file (absolute): /home/matt/.ssh/id_ed25519  
Enter the your JSON Array file path(absolute): /home/matt/repos/forgejo-automation/repolist.json
```

Meaning:

Forgejo username = repository owner on the Forgejo server  
Import key = SSH key used to push into Forgejo  
Export key = SSH key used to clone from GitHub  
JSON path = location of the repo list file  

---

# Temporary Working Directory

The script clones repositories into a working directory called:

`Sync/`

This directory is only used temporarily for cloning and pushing.

After the script finishes, delete it:

`rm -rf Sync`

It is recommended to remove the Sync directory after each run so the next run starts clean.

---

# Summary

This script automates copying repositories from one git remote to another.

Typical use case:

GitHub (export) → Forgejo (import)

It clones repositories from the export source, adds a Forgejo remote, and pushes them to the import destination.
