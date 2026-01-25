#!/bin/bash
# wiki-selector.sh - Selector pane for wikim

# Arguments: <Target_Pane_ID> <Wiki_Title> <TOC_File (ignored)>
TARGET_PANE="$1"
TITLE="$2"
# TOC_FILE is no longer used, as the downloader handles it
# TOC_FILE="$3"

if [ -z "$TARGET_PANE" ] || [ -z "$TITLE" ]; then
    echo "Usage: $0 <Target_Pane_ID> <Wiki_Title> [TOC_File]"
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
    anchor=$(echo "$selection" | tail -n1 | awk -F'|' '{print $2}')
    if [ -n "$anchor" ]; then
        # Control the main pane (w3m)
        # v=toggle line number (hack to clear buffer?), /search, z=center
        tmux send-keys -t "$TARGET_PANE" "v" "/id=\"$anchor\"" "Enter" "v" "z"
    fi
done

# If selector exits, kill the main pane
tmux send-keys -t "$TARGET_PANE" "q" "y" 2>/dev/null
