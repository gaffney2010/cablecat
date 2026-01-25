#!/bin/bash

# cablecat_jump.cgi - Handle wiki jumps via CGI
# This script is executed by the web server (Apache).
# It generates the HTML for the target Wikipedia page.

# Ensure we output headers first
echo "Content-type: text/html; charset=utf-8"
echo ""

# Extract target from query string
# Format: target=URL_ENCODED_TITLE
# We use sed to extract the value
TARGET=$(echo "$QUERY_STRING" | sed -n 's/^.*target=\([^&]*\).*$/\1/p')

if [ -z "$TARGET" ]; then
    echo "<h1>Error: No target particular specified.</h1>"
    exit 0
fi

# Decode the target (URL encoded) to get the Title
# We use python for reliable decoding
DECODED_TITLE=$(echo "$TARGET" | python3 -c "import sys, urllib.parse; print(urllib.parse.unquote(sys.stdin.read().strip()))")

# Configuration
CACHE_DIR="/var/cache/cablecat-wiki"
if [ -f "/etc/cablecat/cablecat.conf" ]; then
    source "/etc/cablecat/cablecat.conf"
fi

# Re-encode specifically for filesystem/API consistency logic used in wiki.sh
# (jq -sRr @uri matches the encoding used there)
ENCODED_TITLE=$(echo "$DECODED_TITLE" | jq -sRr @uri | sed 's/%0A$//')

CACHE_FILE="$CACHE_DIR/${ENCODED_TITLE}.html"

# Serve from cache if available
if [ -f "$CACHE_FILE" ]; then
    cat "$CACHE_FILE"
    exit 0
fi

# If not in cache, we must fetch and convert.
# Use a temporary directory
TMP_DIR=$(mktemp -d)

# 1. Download from Wikipedia
curl -s "https://en.wikipedia.org/w/api.php?action=query&prop=revisions&rvprop=content&format=json&titles=$ENCODED_TITLE" | \
jq -r '.query.pages[].revisions[0]["*"]' > "$TMP_DIR/page.wiki"

# Check validity
if [ ! -s "$TMP_DIR/page.wiki" ] || [ "$(cat "$TMP_DIR/page.wiki")" == "null" ]; then
    echo "<h1>Page not found</h1>"
    echo "<p>Could not fetch article: $DECODED_TITLE</p>"
    rm -rf "$TMP_DIR"
    exit 0
fi

# 2. Convert to HTML
pandoc -f mediawiki -t html "$TMP_DIR/page.wiki" -o "$TMP_DIR/page.html"

# 3. Rewrite links
# We execute the rewrite script. Ensure we use the installed path.
# This ensures resulting links also point to this CGI.
if [ -f "/usr/lib/cablecat-wiki/rewrite_links.py" ]; then
    python3 /usr/lib/cablecat-wiki/rewrite_links.py "$TMP_DIR/page.html"
fi

# 4. Save to cache
if [ -d "$CACHE_DIR" ] && [ -w "$CACHE_DIR" ]; then
    cp "$TMP_DIR/page.html" "$CACHE_FILE"
fi

# 5. Output HTML
cat "$TMP_DIR/page.html"

# Cleanup
rm -rf "$TMP_DIR"
