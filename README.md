```                                                        
               █      ▀▀█                           ▄   
  ▄▄▄    ▄▄▄   █▄▄▄     █     ▄▄▄    ▄▄▄    ▄▄▄   ▄▄█▄▄ 
 █▀  ▀  ▀   █  █▀ ▀█    █    █▀  █  █▀  ▀  ▀   █    █   
 █      ▄▀▀▀█  █   █    █    █▀▀▀▀  █      ▄▀▀▀█    █   
 ▀█▄▄▀  ▀▄▄▀█  ██▄█▀    ▀▄▄  ▀█▄▄▀  ▀█▄▄▀  ▀▄▄▀█    ▀▄▄ 
                                                        
```                                                        

# cablecat
A few little internet TUIs.

## Wiki Viewer (`cablecat-wiki`)

A command-line tool to view Wikipedia pages in `w3m`.

### Installation

To install `cablecat-wiki` and its dependencies (`pandoc >= 3.1.11`, `w3m >= 0.5.3`), run:

```bash
make install
```

This will build a Debian package and install it on your system.

### Uninstallation

To remove `cablecat-wiki`, run:

```bash
make uninstall
```

### Usage

```bash
cablecat-wiki "Wiki_Title"
```

Example:

```bash
cablecat-wiki "ROUGE_(metric)"
```
