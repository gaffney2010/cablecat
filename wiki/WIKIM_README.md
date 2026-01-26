# Wikim Developer Guide

`wikim` is a terminal-based Wikipedia reader that uses `tmux` to provide a split-pane interface with a Table of Contents (TOC) sidebar.

## 1. Architecture Overview

When you run `cablecat-wikim <Topic>`, the following happens:

1.  **Session Isolation**: `wikim.sh` ensures it runs in a dedicated, isolated `tmux` session (`-L socket`). This prevents polluting the user's existing tmux environment and allows for programmatic control.
2.  **Layout Setup**:
    *   **Main Pane (Left)**: Runs `cablecat-wiki` (formerly `wiki.sh`), which renders the Wikipedia article in `w3m`.
    *   **Sidebar Pane (Right)**: Runs `wiki-selector.sh`, which displays the TOC using `fzf`.
3.  **Inter-Process Communication (IPC)**:
    *   The sidebar (`wiki-selector.sh`) controls the main pane by sending keystrokes via `tmux send-keys`.
    *   When you select an item in the sidebar, it sends w3m commands (e.g., `/id="anchor"`) to the left pane to scroll to the specific section.

## 2. Component Roles

| Script | Installed Location | Role |
| :--- | :--- | :--- |
| `wikim.sh` | `/usr/bin/cablecat-wikim` | **Orchestrator**. Sets up the tmux session, splits the window, and launches the sub-components. |
| `wiki.sh` | `/usr/bin/cablecat-wiki` | **Renderer**. Downloads content, converts MediaWiki to HTML (via pandoc), rewrites links, and opens `w3m`. |
| `wiki-selector.sh` | `/usr/lib/cablecat-wiki/` | **Navigator**. Fetches the TOC and uses `fzf` to let the user select a section. Sends commands to the renderer. |
| `wiki-download.sh` | `/usr/lib/cablecat-wiki/` | **Fetcher**. handling caching and downloading of raw Wikitext. |

## 3. Controlling the Instance Programmatically

When `wikim.sh` starts, it writes its unique tmux socket path to `/tmp/wikim_latest_socket`. You can use this to control the instance externally.

### Identifying the Socket
```bash
SOCKET=$(cat /tmp/wikim_latest_socket)
```

### Examples

**1. Close the Sidebar**
```bash
tmux -S "$SOCKET" kill-pane -t 1
```

**2. Send Keys to Main View**
```bash
# Send 'q' to quit w3m in the main pane (index 0)
tmux -S "$SOCKET" send-keys -t 0 "q"
```

**3. Resize Panels**
```bash
tmux -S "$SOCKET" resize-pane -t 1 -x 50  # Set sidebar width to 50 columns
```

## 4. Development Workflow

The scripts include fallback logic to run locally if they are not installed in the system paths.

*   **Local Execution**: You can run `./wikim.sh "Topic"` directly from the source directory. It will look for `wiki-selector.sh` and `wiki-download.sh` in the same directory if `/usr/lib/cablecat-wiki` is missing.
*   **Dependencies**: Ensure you have `tmux`, `fzf`, `w3m`, `pandoc`, and `python3` installed.
*   **Build & Install**: Use the included Makefile.
    *   `make build`: Creates a `.deb` package in `build/`.
    *   `make install`: Installs the package locally (requires sudo).
    *   `make reinstall`: Uninstalls and reinstalls (useful for quick iteration).

## 5. Configuration

Configuration is loaded from `/etc/cablecat/cablecat.conf`. This file is sourced by the scripts, so standard shell variable syntax applies.

Common variables:
*   `CACHE_DIR`: Location for cached wiki pages (default `/var/cache/cablecat-wiki`).
*   `CACHE_RETENTION_DAYS`: Days to keep cached files before automatic deletion (default `3`).
*   `WIKIM_PANE_SIZE`: (Optional) Can be added to control default sidebar width.

**Automatic Cleanup**: The package installs a systemd timer (`cablecat-cleanup.timer`) that runs `cablecat-cleanup.sh` daily to remove old cache files.

## 6. Technical Deep Dive

### Data Flow & Caching
Content fetching is centralized in `wiki-download.sh`.
1.  **Request**: `wiki.sh` or `wiki-selector.sh` requests content (`wikitext` or `toc`).
2.  **Cache Check**: Checks `/var/cache/cablecat-wiki/` for `${TITLE}.wikitext` or `${TITLE}.toc`.
3.  **Download**: If missing, fetches JSON from Wikipedia API, uses `jq` to parse, and saves to cache.
4.  **Concurrency**: Uses `flock` on `/tmp/cablecat-wiki-download.lock` to prevent race conditions during download.

### Navigation Mechanics (The "Selector Hack")
The sidebar (`wiki-selector.sh`) doesn't have direct access to the `w3m` process running in the main pane. It uses a `tmux` hack to drive navigation:
1.  **Selection**: User selects a header in `fzf`. The script extracts the Anchor ID (e.g., `History`).
2.  **Control**: It uses `tmux send-keys` to send a sequence to the main pane:
    *   `v`: Toggle Source View in `w3m`.
    *   `/id="History"`: Search for the ID attribute in the HTML source.
    *   `vv` or `z`: Toggle back / Recenter.
    *   *Note: This relies on `pandoc` generating stable IDs in the HTML.*

### Hyperlink Handling (CGI)
Standard `w3m` cannot handle internal wiki links naturally because the content is generated on the fly.
1.  **Rewriting**: `rewrite_links.py` converts internal links to point to a local CGI script: `http://localhost:8080/cgi-bin/cablecat_jump.cgi?target=...`.
2.  **Execution**: When clicked, `w3m` hits the local web server.
3.  **Jump**: `cablecat_jump.cgi` runs `cablecat-wiki` to render the new page.
    *   *Requirement*: This flow requires a local web server (e.g., Apache) serving `/usr/lib/cgi-bin/`.

## 7. System Dependencies
The following packages are required for full functionality:
*   `tmux`: For session management.
*   `w3m`: For rendering HTML.
*   `pandoc`: For converting MediaWiki to HTML.
*   `fzf`: For the fuzzy-find sidebar.
*   `jq`: For parsing Wikipedia API JSON.
*   `python3`: For link rewriting (`beautifulsoup4` required).
*   `curl`: For downloading content.
*   `apache2` (or similar): To serve the CGI script for link navigation.
