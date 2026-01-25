#!/bin/bash

# Load configuration
if [ -f "/etc/cablecat/cablecat.conf" ]; then
    source "/etc/cablecat/cablecat.conf"
fi

# Set defaults if not present in config
: "${CACHE_DIR:="/var/cache/cablecat-wiki"}"
: "${CACHE_RETENTION_DAYS:=3}"

# Delete files older than CACHE_RETENTION_DAYS
if [ -d "$CACHE_DIR" ]; then
    find "$CACHE_DIR" -type f -mtime +"$CACHE_RETENTION_DAYS" -delete
fi
