# CableCat Wiki
A command-line Wikipedia viewer that downloads pages, converts them to HTML, and opens them in w3m.

## Files
- `wiki.sh`: The main script.
- `cablecat.conf`: Default configuration file.

## Configuration
The script uses a clear configuration precedence to determine behaviors like the cache directory.

### Configuration Precedence
1. **Defaults**: Hardcoded in the script (`/var/cache/cablecat-wiki`).
2. **System Config**: `/etc/cablecat/cablecat.conf` (if it exists).

Configuration files are sourced as shell scripts, so you can override variables directly.


## Usage
```bash
./wiki.sh "Wikipedia Article Title"
```
