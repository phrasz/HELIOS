#!/usr/bin/env bash
#
# PatchTrellis_v4.sh
# Safely replaces the TRELLIS:DATA block in the HTML file using Python 
# to avoid shell/awk escaping issues with large JSON payloads.
#

HTML_FILE="${1:-Trellis.html}"
JSON_FILE="${2:-SE2_TreeData_v4.json}"

if [ ! -f "$HTML_FILE" ]; then
    echo "ERROR: Could not find HTML file '$HTML_FILE'."
    exit 1
fi

if [ ! -f "$JSON_FILE" ]; then
    echo "ERROR: Could not find JSON file '$JSON_FILE'."
    exit 1
fi

# Run Python to do a precise block replacement
python3 - <<EOF
import json
import re

html_path = "$HTML_FILE"
json_path = "$JSON_FILE"

# Load and minify the JSON data
with open(json_path, 'r', encoding='utf-8') as f:
    data_obj = json.load(f)

minified_json = json.dumps(data_obj, separators=(',', ':'))

# Read the HTML file
with open(html_path, 'r', encoding='utf-8') as f:
    html_content = f.read()

# Define the marker boundaries
start_marker = "/* TRELLIS:DATA:START"
end_marker = "/* TRELLIS:DATA:END */"

start_idx = html_content.find(start_marker)
end_idx = html_content.find(end_marker)

if start_idx == -1 or end_idx == -1:
    print("ERROR: Could not find TRELLIS:DATA markers in the HTML file.")
    exit(1)

# Reconstruct the file preserving everything outside the markers
# We keep the comment line for the start marker intact, then inject the data variable
header_comment = html_content[start_idx:html_content.find("*/", start_idx) + 2]
new_block = f"{header_comment}\nconst DATA = {minified_json};"

# Find where the end marker begins so we can snap it right back on
end_block_start = html_content.rfind("/* TRELLIS:DATA:END", 0)

final_html = html_content[:start_idx] + new_block + "\n" + html_content[end_block_start:]

with open(html_path, 'w', encoding='utf-8') as f:
    f.write(final_html)

print("SUCCESS: Patched HTML cleanly with Python.")
EOF
