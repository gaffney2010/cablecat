#!/bin/bash
# wikim - Split-pane Wikipedia viewer with TOC navigation


# 1. ISOLATION: Ensure we run in a dedicated tmux session
#    This allows external scripts to control this instance (e.g., resizing) via the socket.
if [ -z "$WIKIM_ISOLATED" ]; then
    # Create an explicit socket path so we can find it easily later
    SOCKET="/tmp/wikim-socket-$$"
    echo "$SOCKET" > /tmp/wikim_latest_socket    # Re-exec ourselves inside the isolated session
    export WIKIM_ISOLATED=1
    exec tmux -S "$SOCKET" new-session "$(realpath "$0") \"$1\""
fi

# =========================================================================================
# INTERNAL LOGIC (Running inside the isolated tmux)
# =========================================================================================

TITLE="$1"
[ -z "$TITLE" ] && echo "Usage: $0 <Wiki_Title>" && exit 1

# Load configuration (sync with wiki.sh)
if [ -f "/etc/cablecat/cablecat.conf" ]; then
    set -a
    source "/etc/cablecat/cablecat.conf"
    set +a
fi

# Cleanup hook
cleanup() { 
    tmux kill-pane -t "$1" 2>/dev/null; 
}

# MAIN LOGIC: Split window and start components
CURRENT_PANE=$(tmux display-message -p '#{pane_id}')

# Create sidebar
SELECTOR_CMD="/usr/lib/cablecat-wiki/wiki-selector.sh"
if [ ! -x "$SELECTOR_CMD" ]; then
    echo "Error: wikim could not find 'wiki-selector.sh' in /usr/lib/cablecat-wiki"
    exit 1
fi

trap "cleanup $SIDEBAR_PANE" EXIT

# Find and run wiki reader
WIKI_CMD=$(command -v cablecat-wiki)
if [ ! -x "$WIKI_CMD" ]; then
    echo "Error: wikim could not find 'cablecat-wiki'"
    exit 1
fi

"$WIKI_CMD" "$TITLE"
