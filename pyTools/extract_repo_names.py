#!/usr/bin/env python3

import sys
import json

if len(sys.argv) != 3:
    print("usage: extract_repo_names.py <input.json> <output.json>", file=sys.stderr)
    sys.exit(1)

input_file = sys.argv[1]
output_file = sys.argv[2]

with open(input_file, "r", encoding="utf-8") as f:
    data = json.load(f)

if isinstance(data, dict):
    data = [data]

repo_names = []
for repo in data:
    if isinstance(repo, dict) and "html_url" in repo:
        repo_names.append(repo["html_url"])

with open(output_file, "w", encoding="utf-8") as f:
    json.dump(repo_names, f, indent=2)

print(f"wrote {len(repo_names)} repo names to {output_file}")
