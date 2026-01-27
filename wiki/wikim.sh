# =========================================================================================
# PARENT WRAPPER LOGIC
# =========================================================================================

TITLE="$1"
[ -z "$TITLE" ] && echo "Usage: $0 <Wiki_Title>" && exit 1

# Setup Resources
WIKIM_FIFO="/tmp/wikim-fifo-$$"
rm -f "$WIKIM_FIFO"
mkfifo "$WIKIM_FIFO"
export WIKIM_FIFO

# Cleanup logic
cleanup() {
    rm -f "$WIKIM_FIFO"
    if [ -n "$MONITOR_PID" ]; then kill "$MONITOR_PID" 2>/dev/null; fi
    # No need to explicitly kill panes if we kill the session or if attached session ends
}
trap cleanup EXIT

# 1. ISOLATION: Managed Tmux Session
# We always loop back to run as a Wrapper in an isolated tmux server (-S socket).
# This provides:
# 1. Total isolation of keybindings (Q/ESC) so we don't break the user's outer tmux.
# 2. A persistent Controller process (this script) that survives pane respawns.
# 3. Simple "return to previous state" behavior (client exit).

if [ -z "$WIKIM_ISOLATED" ]; then
    # Start a new isolated session
    # Create an explicit socket path so we can find it easily later
    SOCKET="/tmp/wikim-socket-$$"
    export WIKIM_ISOLATED=1
    
    # Monitor: Watches FIFO, kills session on QUIT
    monitor() {
        read _ < "$WIKIM_FIFO"
        # Kill the specific inner session
        tmux -S "$SOCKET" kill-session 2>/dev/null
    }
    monitor &
    MONITOR_PID=$!

    # Start Detached Session with Main Content
    # We run wiki.sh directly in the first pane.
    WIKI_CMD=$(command -v cablecat-wiki)
    [ -x "$WIKI_CMD" ] || WIKI_CMD="$(dirname "$(realpath "$0")")/wiki.sh"
    
    tmux -S "$SOCKET" new-session -d -s wikim "$WIKI_CMD \"$TITLE\""
    
    # Configure Bindings (Global for this isolated server)
    # -n means root table (no prefix needed)
    tmux -S "$SOCKET" bind-key -n Q run-shell "echo QUIT > $WIKIM_FIFO"
    tmux -S "$SOCKET" bind-key -n Escape run-shell "echo QUIT > $WIKIM_FIFO"

    # Setup Sidebar
    # Get Pane ID of the main content (Pane 0)
    MAIN_PANE=$(tmux -S "$SOCKET" list-panes -F "#{pane_id}" | head -n1)
    
    SELECTOR_CMD="/usr/lib/cablecat-wiki/wiki-selector.sh"
    [ -x "$SELECTOR_CMD" ] || SELECTOR_CMD="$(dirname "$(realpath "$0")")/wiki-selector.sh"
    
    # Split window. Note: We must pass MAIN_PANE so selector knows what to respawn.
    tmux -S "$SOCKET" split-window -h -l 25% "$SELECTOR_CMD $MAIN_PANE \"$TITLE\""
    
    # Attach and block until session ends
    tmux -S "$SOCKET" attach-session
    
    # When attach returns (session killed), we exit.
    exit 0
fi

# Fallback for Nested Mode implementation (if execution reaches here)
# or if user calls with WIKIM_ISOLATED=1 manually without the wrapper logic
# (Unexpected, but we can maintain basic split logic)
CURRENT_PANE=$(tmux display-message -p '#{pane_id}')
SELECTOR_CMD="/usr/lib/cablecat-wiki/wiki-selector.sh"
[ -x "$SELECTOR_CMD" ] || SELECTOR_CMD="$(dirname "$(realpath "$0")")/wiki-selector.sh"
tmux split-window -h -l 25% "$SELECTOR_CMD $CURRENT_PANE \"$TITLE\""

WIKI_CMD=$(command -v cablecat-wiki)
[ -x "$WIKI_CMD" ] || WIKI_CMD="$(dirname "$(realpath "$0")")/wiki.sh"
exec "$WIKI_CMD" "$TITLE"
