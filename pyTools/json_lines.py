#!/usr/bin/env python3

import sys
import json

if len(sys.argv) < 2:
    print("usage: json_pick.py field1 [field2 ...]", file=sys.stderr)
    sys.exit(1)

fields = sys.argv[1:]
data = json.load(sys.stdin)

def project(obj):
    if not isinstance(obj, dict):
        return obj
    return {field: obj.get(field) for field in fields}

if isinstance(data, list):
    for item in data:
        print(json.dumps(project(item), ensure_ascii=False))
else:
    print(json.dumps(project(data), ensure_ascii=False))
