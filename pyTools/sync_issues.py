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

def http_request(url, method="GET", headers=None, body=None):
    if headers is None:
        headers = {}

    data = None
    if body is not None:
        data = json.dumps(body).encode("utf-8")

    req = urllib.request.Request(url, data=data, headers=headers, method=method)

    try:
        with urllib.request.urlopen(req) as response:
            raw = response.read().decode("utf-8")
            if raw.strip() == "":
                return {}
            return json.loads(raw)
    except urllib.error.HTTPError as e:
        error_body = e.read().decode("utf-8", errors="replace")
        print(f"HTTP {e.code} {method} {url}", file=sys.stderr)
        print(error_body, file=sys.stderr)
        raise
    except urllib.error.URLError as e:
        print(f"Request failed for {url}: {e}", file=sys.stderr)
        raise


#called on each ticket         
def sync_issue_comments(issue_number, producer_repo_url, consumer_repo_url, type):
    github_path = producer_repo_url.removeprefix("https://" + PRODUCER_DESTINATION_DOMAIN + "/")
    github_path = github_path.rstrip("/")

    forgejo_base = "https://" + CONSUMER_DESTINATION_DOMAIN
    forgejo_path = consumer_repo_url.removeprefix(forgejo_base + "/")
    forgejo_path = forgejo_path.rstrip("/")

    github_comments_url = f"https://api.github.com/repos/{github_path}/{type}/{issue_number}/comments"
    forgejo_comments_url = f"{forgejo_base}/api/v1/repos/{forgejo_path}/{type}/{issue_number}/comments"

    github_headers = {
        "Authorization": f"Bearer {PRODUCER_DESTINATION_TOKEN}",
        "Accept": "application/vnd.github+json"
    }

    forgejo_get_headers = {
        "Authorization": f"token {CONSUMER_DESTINATION_TOKEN}",
        "Accept": "application/json"
    }

    forgejo_post_headers = {
        "Authorization": f"token {CONSUMER_DESTINATION_TOKEN}",
        "Content-Type": "application/json"
    }

    github_comments = http_request(
        github_comments_url,
        method="GET",
        headers=github_headers
    )

    forgejo_comments = http_request(
        forgejo_comments_url,
        method="GET",
        headers=forgejo_get_headers
    )

    existing_comment_bodies = set()

    i = 0
    while i < len(forgejo_comments):
        comment = forgejo_comments[i]
        i += 1

        body = comment.get("body", "")
        existing_comment_bodies.add(body)

    i = 0
    while i < len(github_comments):
        comment = github_comments[i]
        i += 1

        comment_body = comment.get("body", "")
        comment_user = comment.get("user", {}).get("login", "unknown")
        comment_created_at = comment.get("created_at", "")

        import_body = (
            f"> Original author: {comment_user}\n"
            f"> Original created at: {comment_created_at}\n\n"
            f"{comment_body}"
        )

        if import_body in existing_comment_bodies:
            print(f"comment already exists on issue #{issue_number}, skipping")
            continue

        http_request(
            forgejo_comments_url,
            method="POST",
            headers=forgejo_post_headers,
            body={"body": import_body}
        )

        print(f"synced comment for issue #{issue_number} from {comment_user}")




def build_issue_payload(issue):
    payload = {
        "title": issue.get("title", ""),
        "body": issue.get("body") or "",
        "state": issue.get("state", "open")
    }
    return payload


def load_issue_numbers_list(ApiUrl,ApiHeaders):
    forgejo_current_issues = []
    count = 1;
    forge_numbers = set()

    while True:
        targetUrl = ApiUrl + f"&page={count}"
        forgejo_current_issues = http_request(targetUrl, method="GET", headers=ApiHeaders)
        
        if len(forgejo_current_issues) == 0:
            return forge_numbers

        for issue in forgejo_current_issues:
            forge_numbers.add(issue["number"])

        count += 1 



def sync_issues(producer_repo_url, consumer_repo_url):
    github_path = producer_repo_url.removeprefix("https://" + PRODUCER_DESTINATION_DOMAIN + "/")
    github_path = github_path.rstrip("/")

    forgejo_base = "https://" + CONSUMER_DESTINATION_DOMAIN
    forgejo_path = consumer_repo_url.removeprefix(forgejo_base + "/")
    forgejo_path = forgejo_path.rstrip("/")

    github_issues_url = f"https://api.github.com/repos/{github_path}/issues?state=all&per_page=100"
    forgejo_issues_url = f"{forgejo_base}/api/v1/repos/{forgejo_path}/issues"
    forgejo_issues_url_get = f"{forgejo_base}/api/v1/repos/{forgejo_path}/issues?state=all&limit=100" 

    github_headers = {
        "Authorization": f"Bearer {PRODUCER_DESTINATION_TOKEN}",
        "Accept": "application/vnd.github+json"
    }

    forgejo_get_headers = {
        "Authorization": f"token {CONSUMER_DESTINATION_TOKEN}",
        "Accept": "application/json"
    }

    forgejo_headers = {
        "Authorization": f"token {CONSUMER_DESTINATION_TOKEN}",
        "Content-Type": "application/json"
    }

    github_issues = http_request(github_issues_url, method="GET", headers=github_headers)
    github_issues.reverse()

    forge_numbers = load_issue_numbers_list(forgejo_issues_url_get,forgejo_get_headers)
    
    #print(forge_numbers)
    # GitHub returns PRs in /issues too, so skip those.
    print("Begining issue scan")
    i = 0
    while i < len(github_issues):

        issue = github_issues[i]


        i += 1

        if "pull_request" in issue:
            continue
        
        #should now skip pushing currently existing tickets
        currentIssue = issue["number"]
        print(f"Scanning issue Sync Status:{currentIssue}")
        if currentIssue in forge_numbers:
            print(f"Issue#{currentIssue} already exists in the consumer repo");
            print("Syncing issue comments")
            sync_issue_comments(currentIssue,producer_repo_url,consumer_repo_url, "issues")
            print("skipping....")
            continue
        print(f"Current Issue found")

        issue_json = build_issue_payload(issue)
        issue_state = issue_json.get("state", "open")
                
        create_response = http_request(
            forgejo_issues_url,
            method="POST",
            headers=forgejo_headers,
            body=issue_json
        )    

        issue_number = create_response.get("number")

        print("Syncing issue comments")
        sync_issue_comments(issue_number,producer_repo_url,consumer_repo_url, "issues")
        print(f"created issue #{issue_number} with state={issue_state}")
        


        if issue_state == "closed":
            http_request(
                f"{forgejo_issues_url}/{issue_number}",
                method="PATCH",
                headers=forgejo_headers,
                body={"state": "closed"}
            )
            print(f"closed issue #{issue_number}")


# call like this:
# sync_issues(
#     "https://github.com/Mattlavelle966/Playwright-Domain-Specific-Lang",
#     "https://dropadox.sytes.net/net-760/MattLavelle966/Playwright-Domain-Specific-Lang"
# )


if __name__ == "__main__":
    # optional CLI usage:
    # python3 sync_issues.py <github_repo_url> <forgejo_repo_url>
    if len(sys.argv) == 3:
        sync_issues(sys.argv[1], sys.argv[2])
    else:
        print("No CLI args provided. Edit the call in the file or pass 2 repo URLs.")
