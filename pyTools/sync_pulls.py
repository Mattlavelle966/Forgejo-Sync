#!/usr/bin/env python3

import os
import sys
import json
import urllib.request
import urllib.error


PRODUCER_DESTINATION_TOKEN = os.environ["PRODUCER_DESTINATION_TOKEN"]
CONSUMER_DESTINATION_TOKEN = os.environ["CONSUMER_DESTINATION_TOKEN"]
PRODUCER_DESTINATION_DOMAIN = os.environ["PRODUCER_DESTINATION_DOMAIN"]
CONSUMER_DESTINATION_DOMAIN = os.environ["CONSUMER_DESTINATION_DOMAIN"]

from sync_issues import (
    http_request,
    load_issue_numbers_list,
    sync_issue_comments
)


def sync_pulls(producer_repo_url, consumer_repo_url):

    print("syncing pull requests")
    github_path = producer_repo_url.removeprefix("https://" + PRODUCER_DESTINATION_DOMAIN + "/")
    github_path = github_path.rstrip("/")

    forgejo_base = "https://" + CONSUMER_DESTINATION_DOMAIN
    forgejo_path = consumer_repo_url.removeprefix(forgejo_base + "/")
    forgejo_path = forgejo_path.rstrip("/")

    github_pulls_url = f"https://api.github.com/repos/{github_path}/pulls?state=all&per_page=100&page=1"

    forgejo_pulls_url = f"{forgejo_base}/api/v1/repos/{forgejo_path}/pulls"
    forgejo_pulls_url_get = f"{forgejo_base}/api/v1/repos/{forgejo_path}/pulls?state=all&limit=100"

    github_headers = {
        "Authorization": f"Bearer {PRODUCER_DESTINATION_TOKEN}",
        "Accept": "application/vnd.github+json"
    }

    forgejo_headers = {
        "Authorization": f"token {CONSUMER_DESTINATION_TOKEN}",
        "Content-Type": "application/json"
    }


    github_pulls = http_request(
        github_pulls_url,
        method="GET",
        headers=github_headers
    )

    github_pulls.reverse()
    

    try:
        forge_numbers = load_issue_numbers_list(forgejo_pulls_url_get, forgejo_headers)
    except Exception as e:
        print(f"Could not load existing Forgejo pull requests: {e}")
        forge_numbers = [] 
    

    i = 0
    while i < len(github_pulls):
        pr = github_pulls[i]
        i+=1
        pr_number = pr["number"]
        title = pr.get("title", "")
        body = pr.get("body") or ""
        state = pr.get("state", "open")

        head_ref = pr["head"]["ref"]
        base_ref = pr["base"]["ref"]
        merged_at = pr.get("merged_at")
        print("head_ref:", head_ref)
        print("base_ref:", base_ref) 

        print(f"Scanning pull request Sync Status:{pr_number}")
 
        if pr_number in forge_numbers:  
            print(f"PullRequest#{pr_number} already exists in the consumer repo")  
            print("Syncing pull request comments")   


            try:
                sync_issue_comments(pr_number, producer_repo_url, consumer_repo_url,"issues")          
            except Exception:
                pass            

            try:
                sync_issue_comments(pr_number, producer_repo_url, consumer_repo_url, "pulls")
            except Exception:
                pass            
            print("skipping....")
            continue

        pull_json = {
            "title": title,
            "body": body,
            "head": head_ref,
            "base": base_ref
        }
        
        try:
            create_response = http_request(
                forgejo_pulls_url,
                method="POST",
                headers=forgejo_headers,
                body=pull_json
            )
         
            consumer_pr_number = create_response.get("number")  
    
            print("Syncing pull request comments")   
            try:
                sync_issue_comments(consumer_pr_number, producer_repo_url, consumer_repo_url,"issues") 
            except Exeption:
                pass
            try:
                sync_issue_comments(consumer_pr_number, producer_repo_url, consumer_repo_url, "pulls")
            except Exception:
                pass

            
            print(f"created pull request #{consumer_pr_number} with state={state}")


            if state == "closed":
                http_request(
                    f"{forgejo_pulls_url}/{consumer_pr_number}",
                    method="PATCH",
                    headers=forgejo_headers,
                    body={"state": "closed"}
                )
                print(f"closed pull request #{consumer_pr_number}")

            if merged_at is not None:
                print(f"Pull request #{consumer_pr_number} was merged on GitHub, but merge replay is not handled yet")
        except Exception:
            print("response failed")
            pass


    pass


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("usage: sync_pulls.py <producer_repo_url> <consumer_repo_url>")
        sys.exit(1)

    sync_pulls(sys.argv[1], sys.argv[2])
