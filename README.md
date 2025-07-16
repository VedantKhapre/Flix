# Flix

A simple bash script that lets you search for torrents and either stream them directly with `peerflix` + `mpv` or download them with Transmission.

## Features

- 🔍 Search torrents using ThePirateBay API
- 🎬 Stream directly with `peerflix` + `mpv` 
- ⬇️ Download with Transmission
- 🎯 Interactive selection with `fzf`

## Dependencies

**All modes:** `curl` `jq` `fzf` `numfmt`
**Streaming:** `peerflix` `mpv` 
**Download:** `transmission-qt`

## Installation

```bash
# Ubuntu/Debian
sudo apt install curl jq fzf coreutils mpv transmission-qt
npm install -g peerflix

# Arch Linux  
sudo pacman -S curl jq fzf coreutils mpv transmission-qt
npm install -g peerflix

# macOS
brew install curl jq fzf coreutils mpv transmission
npm install -g peerflix

# Make globally available
chmod +x flix.sh
sudo cp flix.sh /usr/local/bin/flix
```

## Usage

```bash
flix "movie name"              # Stream
flix -d "movie name"           # Download
flix                           # Interactive search
flix -h                        # Help
```

## Troubleshooting

- **No results:** Try different search terms or check connection
- **Transmission fails:** Ensure `transmission-qt` is installed
- **Peerflix missing:** Run `npm install -g peerflix`
- **Streaming issues:** Check `mpv` installation and bandwidth

## Security Notes

- The script fetches tracker lists from GitHub (ngosang/trackerslist)
- Uses ThePirateBay API endpoints
- Creates temporary directories with restricted permissions (700)
- Automatically cleans up on exit

## Legal Disclaimer

This script is for educational purposes only. Users are responsible for ensuring they comply with local laws and regulations regarding torrenting and copyright. Only use this script to download/stream content you have the legal right to access.

## License

This script is provided as-is for educational purposes. Use at your own risk.
