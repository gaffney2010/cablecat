#!/bin/bash

# Check if an argument is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <Wiki_Title>"
  exit 1
fi

TITLE="$1"
ENCODED_TITLE=$(echo "$TITLE" | jq -sRr @uri | sed 's/%0A$//')

# Check cache
# Default configuration values
CACHE_DIR="/var/cache/cablecat-wiki"


# Load configuration
# 1. System-wide default configuration
if [ -f "/etc/cablecat/cablecat.conf" ]; then
    # We source it to allow flexible configuration
    source "/etc/cablecat/cablecat.conf"
fi



CACHE_FILE="$CACHE_DIR/${ENCODED_TITLE}.html"

if [ -f "$CACHE_FILE" ]; then
    w3m "$CACHE_FILE"
    exit 0
fi

# Create a temporary directory
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

# Download and extract content
curl -s "https://en.wikipedia.org/w/api.php?action=query&prop=revisions&rvprop=content&format=json&titles=$ENCODED_TITLE" | \
jq -r '.query.pages[].revisions[0]["*"]' > "$TMP_DIR/page.wiki"

# Check if content was found (basic check)
if [ ! -s "$TMP_DIR/page.wiki" ] || [ "$(cat "$TMP_DIR/page.wiki")" == "null" ]; then
    echo "Error: Page not found or empty."
    exit 1
fi

# Convert to HTML
pandoc -f mediawiki -t html "$TMP_DIR/page.wiki" -o "$TMP_DIR/page.html"

# Save to cache if directory exists and is writable
if [ -d "$CACHE_DIR" ] && [ -w "$CACHE_DIR" ]; then
    cp "$TMP_DIR/page.html" "$CACHE_FILE"
fi

# Open with w3m
w3m "$TMP_DIR/page.html"
