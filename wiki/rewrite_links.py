#!/usr/bin/env python3
import sys
import argparse
from bs4 import BeautifulSoup
import urllib.parse
import os

def main():
    parser = argparse.ArgumentParser(description="Rewrite wikilinks to CGI jump scripts.")
    parser.add_argument("file", help="HTML file to process")
    parser.add_argument("--wikim-socket", help="Tmux socket path for wikim mode")
    parser.add_argument("--wikim-selector-pane", help="Selector pane ID for wikim mode")
    parser.add_argument("--wikim-main-pane", help="Main pane ID for wikim mode")
    args = parser.parse_args()

    if not os.path.exists(args.file):
        # Fail silently or verbose? User requested "Execute cablecat-wiki" 
        # but here we are just rewriting. 
        # If file missing, maybe just exit.
        sys.exit(1)

    # Get port from environment or default
    port = int(os.environ.get("PORT", 8080))

    try:
        with open(args.file, "r", encoding="utf-8") as f:
            soup = BeautifulSoup(f, "html.parser")
        
        # Find all wikilinks
        links = soup.find_all("a", attrs={"title": "wikilink"})
        
        for a in links:
            href = a.get("href")
            if href:
                # Avoid rewriting external links
                if not href.startswith(("http:", "https:", "ftp:", "mailto:")):
                    quoted_href = urllib.parse.quote(href)
                    # Use localhost URL to point to CGI
                    cgi_url = f"http://localhost:{port}/cgi-bin/cablecat_jump.cgi?target={quoted_href}"
                    # Add wikim context if present
                    if args.wikim_socket:
                        cgi_url += f"&socket={urllib.parse.quote(args.wikim_socket)}"
                        cgi_url += f"&selector_pane={urllib.parse.quote(args.wikim_selector_pane)}"
                        cgi_url += f"&main_pane={urllib.parse.quote(args.wikim_main_pane)}"
                    a["href"] = cgi_url
        
        with open(args.file, "w", encoding="utf-8") as f:
            f.write(str(soup))

    except Exception as e:
        sys.stderr.write(f"Error rewriting links: {e}\n")
        sys.exit(1)

if __name__ == "__main__":
    main()
