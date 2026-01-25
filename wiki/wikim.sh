#!/bin/bash

# wikim - Split-pane Wikipedia viewer with TOC navigation

# Debug logging
LOGfile="/tmp/wikim.log"
exec 2>>"$LOGfile"
echo "[$(date)] Running with args: $@" >> "$LOGfile"

# Helper functions
run_selector() {
    local target_pane="$1"
    local title="$2"
    local toc_file="$3"
    
    echo "Waiting for TOC file: $toc_file" >> "$LOGfile"
    # Wait for TOC file to be created by wiki.sh
    while [ ! -f "$toc_file" ]; do
        sleep 0.5
        # Check if target pane is dead
        if ! tmux list-panes -t "$target_pane" &>/dev/null; then
             echo "Target pane $target_pane died, exiting selector." >> "$LOGfile"
             exit 0
        fi
    done
    echo "TOC file found." >> "$LOGfile"

    while true; do
        # Use fzf to select a section
        # Input format: Index Title |Anchor
        echo "Launching fzf on $toc_file" >> "$LOGfile"
        selection=$(cat "$toc_file" | fzf --delimiter='\|' --with-nth=1 --expect=enter)
        fzf_ret=$?
        echo "fzf returned $fzf_ret" >> "$LOGfile"
        
        if [ $fzf_ret -ne 0 ]; then
            break
        fi

        key=$(echo "$selection" | head -n1)
        line=$(echo "$selection" | tail -n1)
        
        if [ -n "$line" ]; then
            anchor=$(echo "$line" | awk -F'|' '{print $2}')
            
            # Send keys to the target pane
            tmux send-keys -t "$target_pane" "v"
            tmux send-keys -t "$target_pane" "/id=\"$anchor\"" "Enter"
            tmux send-keys -t "$target_pane" "v"
            tmux send-keys -t "$target_pane" "z"
        fi
    done
    
    # If we exit the loop (user quit fzf), we should close the main wiki pane too
    cur_cmd=$(tmux display-message -p -t "$target_pane" "#{pane_current_command}" 2>/dev/null)
    echo "Main pane cmd: $cur_cmd" >> "$LOGfile"
    if [[ "$cur_cmd" == "w3m" ]] || [[ "$cur_cmd" == *"wiki"* ]]; then
        tmux send-keys -t "$target_pane" "q" "y"
    fi
}

cleanup_and_exit() {
    local sidebar="$1"
    echo "Cleaning up sidebar $sidebar" >> "$LOGfile"
    tmux kill-pane -t "$sidebar" 2>/dev/null
}

# Check for internal selector mode
if [ "$1" == "--selector" ]; then
    echo "Entering selector mode" >> "$LOGfile"
    echo "Target Pane: $2, Title: $3, TOC: $4" >> "$LOGfile"
    run_selector "$2" "$3" "$4"
    ret=$?
    echo "Selector exited with $ret" >> "$LOGfile"
    exit $ret
fi

if [ -z "$1" ]; then
    echo "Usage: $0 <Wiki_Title>"
    exit 1
fi

TITLE="$1"
CACHE_DIR="/var/cache/cablecat-wiki"
ENCODED_TITLE=$(echo "$TITLE" | jq -sRr @uri | sed 's/%0A$//')
TOC_FILE="$CACHE_DIR/${ENCODED_TITLE}.html.toc"
echo "TOC File: $TOC_FILE" >> "$LOGfile"

# Ensure tmux is available
if ! command -v tmux &> /dev/null; then
    echo "Error: tmux is required but not installed." >> "$LOGfile"
    echo "Error: tmux is required but not installed."
    exit 1
fi

# Ensure fzf is available
if ! command -v fzf &> /dev/null; then
    echo "Error: fzf is required but not installed." >> "$LOGfile"
    echo "Error: fzf is required but not installed."
    exit 1
fi

# Check if we are running in our isolated environment
if [ -z "$WIKIM_ISOLATED" ]; then
    # We are NOT in the isolated environment.
    # 1. Create a unique socket name based on PID to allow multiple independent instances if needed.
    SOCKET_NAME="wikim_$$"
    SOCKET_PATH="/tmp/$SOCKET_NAME" # Approximate path, tmux -L creates it usually in /tmp/tmux-<uid>/... or similar, 
                                    # BUT -L actually specifies a socket name/path. 
                                    # If we use a full path with -S it's explicit.
                                    # However, -L is easier for "named" sockets relative to TMPDIR. 
                                    # Let's use -S with an explicit path for absolute certainty and ease of saving.
    
    REAL_SOCKET_PATH="/tmp/wikim-socket-$$"
    
    # 2. Save the socket path for the developer
    echo "$REAL_SOCKET_PATH" > /tmp/wikim_latest_socket
    
    echo "Starting isolated wikim session..."
    echo "Socket: $REAL_SOCKET_PATH" >> "$LOGfile"

    # 3. Exec into tmux using this socket
    # We pass the same arguments.
    # We set WIKIM_ISOLATED=1 to prevent infinite recursion.
    export WIKIM_ISOLATED=1
    
    # Resolve absolute path
    SELF=$(realpath "$0")
    
    # Start new session attached
    exec tmux -S "$REAL_SOCKET_PATH" new-session "$SELF \"$TITLE\""
fi

# =========================================================================================
# INTERNAL LOGIC (Running inside the isolated tmux)
# =========================================================================================

# At this point, we are GUARANTEED to be inside our own dedicated tmux server (socket).
# pane_id will likely be %0 if it's the first pane.

CURRENT_PANE=$(tmux display-message -p '#{pane_id}')

# Resolve absolute path to self
SELF=$(realpath "$0")
echo "Self: $SELF" >> "$LOGfile"

# Split the current pane
# We call ourselves with --selector flag
SIDEBAR_PANE=$(tmux split-window -h -l 25% -d -P -F "#{pane_id}" "$SELF --selector $CURRENT_PANE \"$TITLE\" \"$TOC_FILE\"")
echo "Started sidebar pane: $SIDEBAR_PANE" >> "$LOGfile"

# Set a trap to cleanup
trap "cleanup_and_exit $SIDEBAR_PANE" EXIT

# Run wiki.sh
script_dir=$(dirname "$(realpath "$0")")
if command -v wiki &> /dev/null; then
    WIKI_CMD="wiki"
elif command -v cablecat-wiki &> /dev/null; then
    WIKI_CMD="cablecat-wiki"
elif [ -f "$script_dir/wiki.sh" ]; then
    WIKI_CMD="$script_dir/wiki.sh"
else
    echo "Error: Could not find wiki, cablecat-wiki or wiki.sh"
    exit 1
fi

echo "Running Wiki CMD: $WIKI_CMD" >> "$LOGfile"
"$WIKI_CMD" "$TITLE"
