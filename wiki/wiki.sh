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
    set -a
    source "/etc/cablecat/cablecat.conf"
    set +a
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
# Download, parse, and extract content
# fetching all props needed: wikitext for content, sections for TOC
curl -s "https://en.wikipedia.org/w/api.php?action=parse&prop=wikitext|sections&format=json&page=$ENCODED_TITLE" > "$TMP_DIR/response.json"

# Extract wikitext
jq -r '.parse.wikitext["*"]' "$TMP_DIR/response.json" > "$TMP_DIR/page.wiki"

# Extract TOC if available and format for fzf usage
# Format: [Index] Title | Anchor
jq -r '.parse.sections[] | "\(.index) \(.line) |\(.anchor)"' "$TMP_DIR/response.json" > "$CACHE_FILE.toc" 2>/dev/null

# Check if content was found (basic check)
if [ ! -s "$TMP_DIR/page.wiki" ] || [ "$(cat "$TMP_DIR/page.wiki")" == "null" ]; then
    echo "Error: Page not found or empty."
    exit 1
fi

# Convert to HTML
pandoc -f mediawiki -t html "$TMP_DIR/page.wiki" -o "$TMP_DIR/page.html"

# Rewrite links for valid w3m navigation
python3 /usr/lib/cablecat-wiki/rewrite_links.py "$TMP_DIR/page.html"

# Save to cache if directory exists and is writable
if [ -d "$CACHE_DIR" ] && [ -w "$CACHE_DIR" ]; then
    cp "$TMP_DIR/page.html" "$CACHE_FILE"
fi

w3m "$TMP_DIR/page.html"
