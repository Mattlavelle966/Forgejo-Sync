#!/usr/bin/env python3

import sys
import json

if len(sys.argv) != 2:
    print("usage: json_finder.py key", file=sys.stderr)
    sys.exit(1)

key = sys.argv[1]
data = json.load(sys.stdin)

value = ""
if isinstance(data, dict):
    value = data.get(key, "")

if value is None:
    print("")
elif isinstance(value, (dict, list)):
    print(json.dumps(value, ensure_ascii=False))
else:
    print(value)
