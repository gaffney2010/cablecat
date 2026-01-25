#!/bin/bash
# wiki-download.sh - Handles downloading and caching of Wikipedia content

# Exit on error
set -e

# Arguments
TITLE="$1"
FORMAT="$2" # "wikitext" or "toc"

if [ -z "$TITLE" ] || [ -z "$FORMAT" ]; then
    echo "Usage: $0 <Wiki_Title> <Format>" >&2
    echo "Format must be 'wikitext' or 'toc'" >&2
    exit 1
fi

# Configuration
CACHE_DIR="/var/cache/cablecat-wiki"
if [ -f "/etc/cablecat/cablecat.conf" ]; then
    set -a
    source "/etc/cablecat/cablecat.conf"
    set +a
fi

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"

ENCODED_TITLE=$(echo "$TITLE" | jq -sRr @uri | sed 's/%0A$//')
WIKITEXT_FILE="$CACHE_DIR/${ENCODED_TITLE}.wikitext"
TOC_FILE="$CACHE_DIR/${ENCODED_TITLE}.toc"
LOCK_FILE="/tmp/cablecat-wiki-download.lock"

# Acquire global lock
exec 200>"$LOCK_FILE"
flock -x 200

# Function to check if we can return immediately
check_cache() {
    if [ "$FORMAT" == "wikitext" ] && [ -f "$WIKITEXT_FILE" ] && [ -s "$WIKITEXT_FILE" ]; then
        cat "$WIKITEXT_FILE"
        exit 0
    fi
    if [ "$FORMAT" == "toc" ] && [ -f "$TOC_FILE" ] && [ -s "$TOC_FILE" ]; then
        cat "$TOC_FILE"
        exit 0
    fi
}

# Initial check
check_cache

# If not found, download
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

# Check internet connection or failure early? curl will fail if no connection.

# Download wikitext and sections
# Using the same API call as original wiki.sh
URL="https://en.wikipedia.org/w/api.php?action=parse&prop=wikitext|sections&format=json&page=$ENCODED_TITLE"
curl -s "$URL" > "$TMP_DIR/response.json"

# Extract wikitext
jq -r '.parse.wikitext["*"]' "$TMP_DIR/response.json" > "$WIKITEXT_FILE"

# Extract TOC
# Format: [Index] Title |Anchor
jq -r '.parse.sections[] | "\(.index) \(.line) |\(.anchor)"' "$TMP_DIR/response.json" > "$TOC_FILE" 2>/dev/null

# Validate download
if [ ! -s "$WIKITEXT_FILE" ] || [ "$(cat "$WIKITEXT_FILE")" == "null" ]; then
    # Download failed or page empty, cleanup
    rm -f "$WIKITEXT_FILE" "$TOC_FILE"
    echo "Error: Page not found or empty." >&2
    exit 1
fi

# Return requested content
if [ "$FORMAT" == "wikitext" ]; then
    cat "$WIKITEXT_FILE"
elif [ "$FORMAT" == "toc" ]; then
    cat "$TOC_FILE"
else
    echo "Unknown format: $FORMAT" >&2
    exit 1
fi
