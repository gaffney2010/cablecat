#!/bin/bash

# cablecat_jump.cgi - Handle wiki jumps via CGI
# This script is executed by the web server (Apache).
# It delegates the logic to /usr/bin/wiki (which supports non-interactive output).

# Ensure we output headers first
echo "Content-type: text/html; charset=utf-8"
echo ""

# Extract target from query string
# Format: target=URL_ENCODED_TITLE
TARGET=$(echo "$QUERY_STRING" | sed -n 's/^.*target=\([^&]*\).*$/\1/p')

if [ -z "$TARGET" ]; then
    echo "<h1>Error: No target particular specified.</h1>"
    exit 0
fi

# Decode the target (URL encoded) to get the Title
# We use python for reliable decoding
DECODED_TITLE=$(echo "$TARGET" | python3 -c "import sys, urllib.parse; print(urllib.parse.unquote(sys.stdin.read().strip()))")

# Call the external wiki script
# The wiki script is expected to output the HTML content to stdout when not in a TTY.
if [ -x "/usr/bin/cablecat-wiki" ]; then
    /usr/bin/cablecat-wiki --stdout "$DECODED_TITLE"
else
    echo "<h1>Error: cablecat-wiki executable not found.</h1>"
fi
