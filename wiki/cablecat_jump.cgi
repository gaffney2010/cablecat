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

# Extract wikim parameters if present (for multi-pane mode)
SOCKET=$(echo "$QUERY_STRING" | sed -n 's/^.*socket=\([^&]*\).*$/\1/p')
SELECTOR_PANE=$(echo "$QUERY_STRING" | sed -n 's/^.*selector_pane=\([^&]*\).*$/\1/p')
MAIN_PANE=$(echo "$QUERY_STRING" | sed -n 's/^.*main_pane=\([^&]*\).*$/\1/p')

# Decode wikim parameters if present
if [ -n "$SOCKET" ]; then
    DECODED_SOCKET=$(echo "$SOCKET" | python3 -c "import sys, urllib.parse; print(urllib.parse.unquote(sys.stdin.read().strip()))")
    DECODED_SELECTOR_PANE=$(echo "$SELECTOR_PANE" | python3 -c "import sys, urllib.parse; print(urllib.parse.unquote(sys.stdin.read().strip()))")
    DECODED_MAIN_PANE=$(echo "$MAIN_PANE" | python3 -c "import sys, urllib.parse; print(urllib.parse.unquote(sys.stdin.read().strip()))")
fi

# Call the external wiki script
# The wiki script is expected to output the HTML content to stdout when not in a TTY.
if [ -x "/usr/bin/cablecat-wiki" ]; then
    if [ -n "$DECODED_SOCKET" ]; then
        # Wikim mode: pass context so subsequent links also have it
        /usr/bin/cablecat-wiki --stdout \
            --wikim-socket "$DECODED_SOCKET" \
            --wikim-selector-pane "$DECODED_SELECTOR_PANE" \
            --wikim-main-pane "$DECODED_MAIN_PANE" \
            "$DECODED_TITLE"

        # Respawn the selector pane with the new title
        SELECTOR_CMD="/usr/lib/cablecat-wiki/wiki-selector.sh"
        tmux -S "$DECODED_SOCKET" respawn-pane -k -t "$DECODED_SELECTOR_PANE" \
            "$SELECTOR_CMD $DECODED_MAIN_PANE \"$DECODED_TITLE\""
    else
        /usr/bin/cablecat-wiki --stdout "$DECODED_TITLE"
    fi
else
    echo "<h1>Error: cablecat-wiki executable not found.</h1>"
fi
