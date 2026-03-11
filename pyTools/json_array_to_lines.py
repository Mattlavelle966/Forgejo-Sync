#!/usr/bin/env python3

import sys
import json

if len(sys.argv) != 2:
    print("usage: json_array_to_lines.py <input.json>", file=sys.stderr)
    sys.exit(1)

input_file = sys.argv[1]

with open(input_file, "r", encoding="utf-8") as f:
    data = json.load(f)

if not isinstance(data, list):
    print("error: top-level JSON must be an array", file=sys.stderr)
    sys.exit(1)

for item in data:
    if isinstance(item, str):
        print(item)
    else:
        print(json.dumps(item, ensure_ascii=False))
