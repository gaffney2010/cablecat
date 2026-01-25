#!/bin/bash

# Check if an argument is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <Wiki_Title>"
  exit 1
fi

TITLE="$1"
# Load configuration
# 1. System-wide default configuration
if [ -f "/etc/cablecat/cablecat.conf" ]; then
    # We source it to allow flexible configuration
    set -a
    source "/etc/cablecat/cablecat.conf"
    set +a
fi

# Create a temporary directory
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

# Download and extract content
# Fetch wikitext using the centralized downloader
# Use the installed version
DOWNLOADER="/usr/lib/cablecat-wiki/wiki-download.sh"

# If for some reason we are running in dev mode and it's not installed, try local
if [ ! -x "$DOWNLOADER" ]; then
    # Fallback for development/testing
    DOWNLOADER="$(dirname "$0")/wiki-download.sh"
fi

"$DOWNLOADER" "$TITLE" "wikitext" > "$TMP_DIR/page.wiki"

# Check if content was found
if [ ! -s "$TMP_DIR/page.wiki" ]; then
    echo "Error: Page not found or empty."
    exit 1
fi

# Convert to HTML
pandoc -f mediawiki -t html "$TMP_DIR/page.wiki" -o "$TMP_DIR/page.html"

# Rewrite links for valid w3m navigation
python3 /usr/lib/cablecat-wiki/rewrite_links.py "$TMP_DIR/page.html"



w3m "$TMP_DIR/page.html"
