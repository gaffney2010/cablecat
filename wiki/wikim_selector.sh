#!/bin/bash
# wikim_selector.sh - Selector pane for wikim

# Debug logging
LOG="/tmp/wikim.debug"
log() { echo "[$(date '+%H:%M:%S')] [SELECTOR] $@" >> "$LOG"; }

# Arguments: <Target_Pane_ID> <Wiki_Title (unused but passed)> <TOC_File>
TARGET_PANE="$1"
TITLE="$2"
TOC_FILE="$3"

if [ -z "$TARGET_PANE" ] || [ -z "$TOC_FILE" ]; then
    echo "Usage: $0 <Target_Pane_ID> <Wiki_Title> <TOC_File>"
    log "Error: Missing arguments. Got: $@"
    exit 1
fi

log "Selector started. Target: $TARGET_PANE, TOC: $TOC_FILE"
echo "Waiting for TOC..."

# Wait for TOC
waited=0
while [ ! -f "$TOC_FILE" ]; do
    sleep 0.2
    waited=$((waited+1))
    # Exit if main pane dies
    if ! tmux list-panes -t "$TARGET_PANE" &>/dev/null; then
         log "Target pane died. Exiting selector."
         exit 0
    fi
    if [ $waited -gt 50 ]; then # Log every ~10s
         log "Still waiting for TOC..."
         waited=0
    fi
done

log "TOC found. Launching fzf loop."

while true; do
    # fzf selector
    # We cat the file. If it's empty, fzf shows 0/0.
    selection=$(cat "$TOC_FILE" | fzf --delimiter='\|' --with-nth=1 --expect=enter) 
    ret=$?
    
    if [ $ret -ne 0 ]; then
         log "fzf exited with code $ret. Quitting."
         break
    fi
    
    # Parse selection: "Index Title |Anchor"
    anchor=$(echo "$selection" | tail -n1 | awk -F'|' '{print $2}')
    log "Selected anchor: $anchor"
    
    if [ -n "$anchor" ]; then
        # Control the main pane (w3m)
        # v=toggle line number (hack to clear buffer?), /search, z=center
        tmux send-keys -t "$TARGET_PANE" "v" "/id=\"$anchor\"" "Enter" "v" "z"
    fi
done

# If selector exits, kill the main pane
tmux send-keys -t "$TARGET_PANE" "q" "y" 2>/dev/null
