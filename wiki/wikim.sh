#!/bin/bash
# wikim - Split-pane Wikipedia viewer with TOC navigation

# Debug logging
LOG="/tmp/wikim.debug"
log() { echo "[$(date '+%H:%M:%S')] $@" >> "$LOG"; }

# 1. ISOLATION: Ensure we run in a dedicated tmux session
#    This allows external scripts to control this instance (e.g., resizing) via the socket.
if [ -z "$WIKIM_ISOLATED" ]; then
    # Create an explicit socket path so we can find it easily later
    SOCKET="/tmp/wikim-socket-$$"
    echo "$SOCKET" > /tmp/wikim_latest_socket
    log "Starting isolated session on socket: $SOCKET"
    
    # Re-exec ourselves inside the isolated session
    export WIKIM_ISOLATED=1
    exec tmux -S "$SOCKET" new-session "$(realpath "$0") \"$1\""
fi

# =========================================================================================
# INTERNAL LOGIC (Running inside the isolated tmux)
# =========================================================================================

TITLE="$1"
[ -z "$TITLE" ] && echo "Usage: $0 <Wiki_Title>" && exit 1

log "Internal logic started for: $TITLE"

# ENABLE MOUSE for easier pane switching in nested sessions
tmux set -g mouse on 2>/dev/null

# Load configuration (sync with wiki.sh)
CACHE_DIR="/var/cache/cablecat-wiki"
if [ -f "/etc/cablecat/cablecat.conf" ]; then
    log "Loading config from /etc/cablecat/cablecat.conf"
    set -a
    source "/etc/cablecat/cablecat.conf"
    set +a
fi

# Check for custom cache dir env var as well if set by source
log "Using CACHE_DIR: $CACHE_DIR"

TOC_FILE="$CACHE_DIR/$(echo "$TITLE" | jq -sRr @uri | sed 's/%0A$//').html.toc"
SELF=$(realpath "$0")

# Selector function (runs in the sidebar pane)
run_selector() {
    local target_pane="$1"
    local toc_file="$2"
    
    log "Selector started. Target: $target_pane, TOC: $toc_file"
    echo "Waiting for TOC..."
    
    # Wait for TOC
    local waited=0
    while [ ! -f "$toc_file" ]; do
        sleep 0.2
        waited=$((waited+1))
        # Exit if main pane dies
        if ! tmux list-panes -t "$target_pane" &>/dev/null; then
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
        selection=$(cat "$toc_file" | fzf --delimiter='\|' --with-nth=1 --expect=enter) 
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
            tmux send-keys -t "$target_pane" "v" "/id=\"$anchor\"" "Enter" "v" "z"
        fi
    done
    
    # If selector exits, kill the main pane
    tmux send-keys -t "$target_pane" "q" "y" 2>/dev/null
}

# Cleanup hook
cleanup() { 
    log "Cleanup called for pane $1"
    tmux kill-pane -t "$1" 2>/dev/null; 
}

# MODE CHECK: Are we the sidebar selector?
if [ "$1" == "--selector" ]; then
    run_selector "$2" "$4"
    exit 0
fi

# MAIN LOGIC: Split window and start components
CURRENT_PANE=$(tmux display-message -p '#{pane_id}')
log "Main pane ID: $CURRENT_PANE"

# Create sidebar
SIDEBAR_PANE=$(tmux split-window -h -l 25% -d -P -F "#{pane_id}" "$SELF --selector $CURRENT_PANE \"$TITLE\" \"$TOC_FILE\"")
log "Sidebar launched: $SIDEBAR_PANE"
trap "cleanup $SIDEBAR_PANE" EXIT

# Find and run wiki reader
WIKI_CMD=$(command -v wiki || command -v cablecat-wiki || echo "$(dirname "$SELF")/wiki.sh")
if [ ! -x "$WIKI_CMD" ]; then
    echo "Error: wikim could not find 'wiki', 'cablecat-wiki', or 'wiki.sh'"
    log "Error: Wiki command not found"
    exit 1
fi

log "Running wiki command: $WIKI_CMD"
"$WIKI_CMD" "$TITLE"
