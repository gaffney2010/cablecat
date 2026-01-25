# Wikim Developer Guide

`wikim.sh` now runs in an isolated tmux session to prevent pollution of your main terminal environment. This isolation is achieved using `tmux -L <socket_name>`.

## Controlling the Instance Programmatically

When `wikim.sh` starts, it writes the path to its tmux socket to `/tmp/wikim_latest_socket`. You can use this socket path to send commands to the running instance from any other terminal.

### Identifying the Socket
The socket path is dynamic (based on PID) to allow multiple instances, but the *most recently started* instance's socket is always recorded here:

```bash
cat /tmp/wikim_latest_socket
```

### Examples

**1. Close the Right Panel (Sidebar/TOC)**
The sidebar is typically pane index `1` (or the right-most pane).

```bash
SOCKET=$(cat /tmp/wikim_latest_socket)
tmux -S "$SOCKET" kill-pane -t 1
```

**2. Send Keys to the Left Panel (Main Wiki View)**
The main wiki view is typically part of pane index `0`.

```bash
SOCKET=$(cat /tmp/wikim_latest_socket)
# Quit w3m or the current pager
tmux -S "$SOCKET" send-keys -t 0 "q"
```

**3. Resize Panels**
To give the sidebar more space:

```bash
SOCKET=$(cat /tmp/wikim_latest_socket)
tmux -S "$SOCKET" resize-pane -t 1 -x 50
```

## Internal Architecture

- **Isolation**: `wikim.sh` detects if `WIKIM_ISOLATED` is set. If not, it re-execs itself inside a new `tmux -L ...` session. 
- **Socket**: The socket is created in `/tmp/` (standard tmux behavior for `-L`), and its location is logged for your convenience.
