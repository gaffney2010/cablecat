#!/bin/bash
# wiki-search.sh - Search Wikipedia and open result with cablecat-wikim

QUERY="$1"

if [ -z "$QUERY" ]; then
    echo "Usage: $0 \"search terms\""
    exit 1
fi

# URL encode the query
ENCODED_QUERY=$(printf '%s' "$QUERY" | jq -sRr @uri)

# Search Wikipedia using the opensearch API
API_URL="https://en.wikipedia.org/w/api.php?action=opensearch&search=${ENCODED_QUERY}&limit=20&format=json"

# Fetch search results
RESPONSE=$(curl -s "$API_URL")

if [ -z "$RESPONSE" ]; then
    echo "Error: Failed to fetch search results"
    exit 1
fi

# Parse JSON response: [query, [titles], [descriptions], [urls]]
# Extract titles (second array element)
TITLES=$(echo "$RESPONSE" | jq -r '.[1][]')

if [ -z "$TITLES" ]; then
    echo "No results found for: $QUERY"
    exit 1
fi

# Present titles with fzf
SELECTION=$(echo "$TITLES" | fzf --prompt="Wikipedia: ")

if [ -n "$SELECTION" ]; then
    # Find cablecat-wikim command
    WIKIM_CMD=$(command -v cablecat-wikim)
    if [ -z "$WIKIM_CMD" ]; then
        # Fallback for dev environment
        WIKIM_CMD="$(dirname "$(realpath "$0")")/wikim.sh"
    fi

    exec "$WIKIM_CMD" "$SELECTION"
fi
