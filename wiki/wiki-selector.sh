#!/bin/bash
# wiki-selector.sh - Selector pane for wikim

# Arguments: <Target_Pane_ID> <Wiki_Title>
TARGET_PANE="$1"
TITLE="$2"

if [ -z "$TARGET_PANE" ] || [ -z "$TITLE" ]; then
    echo "Usage: $0 <Target_Pane_ID> <Wiki_Title>"
    exit 1
fi

DOWNLOADER="/usr/lib/cablecat-wiki/wiki-download.sh"
# Fallback for dev
if [ ! -x "$DOWNLOADER" ]; then
    DOWNLOADER="$(dirname "$0")/wiki-download.sh"
fi

# Loop for fzf
# We don't need to manually wait for a file anymore because the downloader script
# handles locking and waiting for the download if necessary.

while true; do
    # fzf selector
    # Call the downloader to stream the TOC content
    selection=$("$DOWNLOADER" "$TITLE" "toc" | fzf --delimiter='\|' --with-nth=1 --expect=enter) 
    ret=$?
    
    if [ $ret -ne 0 ]; then
         break
    fi
    
    # Parse selection: "Index Title |Anchor"
    # We want to display the Title but use the Anchor (ID) for navigation.
    # Note: MediaWiki anchors are like "Political_issues", but Pandoc generates "political_issues" (lowercase).
    # We use bash substitution to reliably get everything after the last pipe, handling titles with pipes.
    last_line=$(echo "$selection" | tail -n1)
    anchor="${last_line##*|}"
    
    if [ -n "$anchor" ]; then
        # Convert to lowercase to match Pandoc's ID generation
        anchor=$(echo "$anchor" | tr '[:upper:]' '[:lower:]')

        # Close existing instance and reopen with specific ID
        WIKI_CMD="cablecat-wiki"

        # Escape arguments for the shell command string
        TITLE_ESC=$(printf %q "$TITLE")
        ANCHOR_ESC=$(printf %q "$anchor")

        tmux respawn-pane -k -t "$TARGET_PANE" "$WIKI_CMD --id $ANCHOR_ESC $TITLE_ESC"
    fi
done

# If selector exits, kill the main pane
tmux send-keys -t "$TARGET_PANE" "q" "y" 2>/dev/null
