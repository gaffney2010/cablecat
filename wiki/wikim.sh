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

# Cleanup hook
cleanup() { 
    log "Cleanup called for pane $1"
    tmux kill-pane -t "$1" 2>/dev/null; 
}

# MAIN LOGIC: Split window and start components
CURRENT_PANE=$(tmux display-message -p '#{pane_id}')
log "Main pane ID: $CURRENT_PANE"

# Create sidebar
SELECTOR_CMD=$(command -v cablecat-wikim-selector || command -v wikim-selector || echo "$(dirname "$SELF")/wikim_selector.sh")
if [ ! -x "$SELECTOR_CMD" ]; then
    echo "Error: wikim could not find 'cablecat-wikim-selector', 'wikim-selector' or 'wikim_selector.sh'"
    log "Error: Selector command not found"
    exit 1
fi

SIDEBAR_PANE=$(tmux split-window -h -l 25% -d -P -F "#{pane_id}" "$SELECTOR_CMD $CURRENT_PANE \"$TITLE\" \"$TOC_FILE\"")
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
