#!/bin/bash

set -euo pipefail

DOWNLOAD_MODE=false
API_URL="https://apibay.org/q.php?q="
TEMP_DIR="/tmp/torrent-stream-$$"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

log_info() { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1" >&2; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1" >&2; }
die() { log_error "$1"; cleanup 1; }

cleanup() {
    log_info "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR" 2>/dev/null
    jobs -p | xargs -r kill 2>/dev/null
    exit "${1:-0}"
}

mkdir -p "$TEMP_DIR"
chmod 700 "$TEMP_DIR"
trap cleanup INT TERM EXIT HUP

urlencode() {
    echo -n "$1" | jq -sRr @uri
}

fetch_trackers() {
    log_info "Fetching dynamic tracker list..."
    local tracker_list
    tracker_list=$(curl -sL 'https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all.txt' | awk 'NF' | sed 's#^#\&tr=#' | tr -d '\n')
    if [ -z "$tracker_list" ]; then
        log_warn "Could not fetch dynamic trackers, using a fallback list."
        echo "&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337&tr=udp%3A%2F%2F9.rarbg.to%3A2810"
    else
        echo "$tracker_list"
    fi
}

search_torrents() {
    local query="$1"
    local results_file="$2"
    local temp_file="$TEMP_DIR/api_results.json"
    local user_agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"

    log_info "Searching for '$search_term'..."
    local api_endpoint="${API_URL}${query}"

    if ! curl -s --max-time 15 -A "$user_agent" -H "Accept: application/json" "$api_endpoint" > "$temp_file"; then
        log_error "Failed to fetch results from the API."
        return 1
    fi

    if jq -e '. | length > 0 and .[0].id != "0"' "$temp_file" > /dev/null 2>&1; then
        log_info "Processing found results..."

        local jq_filter='.[] | select((.seeders|tonumber) > 0 and (.category | tonumber) < 500) | [.info_hash, .name, .seeders, .leechers, .size] | @tsv'

        jq -r "$jq_filter" "$temp_file" |
        while IFS=$'\t' read -r info_hash name seeders leechers size; do
            local hr_size
            hr_size=$(numfmt --to=iec-i --suffix=B --format="%.2f" "$size" 2>/dev/null || echo "$size")
            info_hash=$(echo "$info_hash" | tr '[:upper:]' '[:lower:]')
            printf "%s\t%s\t%s\t%s\t%s\n" "$info_hash" "$name" "$seeders" "$leechers" "$hr_size" >> "$results_file"
        done
        return 0
    else
        log_warn "No valid results found or API returned an empty response."
        return 1
    fi
}

check_dependencies() {
    log_info "Checking for required tools..."
    local required_tools="curl jq fzf numfmt"

    if $DOWNLOAD_MODE; then
        required_tools+=" transmission-remote"
    else
        required_tools+=" peerflix mpv"
    fi

    for cmd in $required_tools; do
        command -v "$cmd" >/dev/null 2>&1 || die "$cmd is required but is not installed. Please install it."
    done
}

check_dependencies

while [[ $# -gt 0 && "$1" =~ ^- ]]; do
    case $1 in
        -d | --download )
            DOWNLOAD_MODE=true
            log_info "Download mode enabled - will open in Transmission."
            ;;
        -h | --help )
            echo "Usage: $0 [-d|--download] [search term]"
            echo "  -d, --download    Download torrent using Transmission instead of streaming."
            echo "  -h, --help        Show this help message."
            exit 0
            ;;
        * )
            die "Unknown option: $1"
            ;;
    esac
    shift
done

clear

if [ $# -eq 0 ]; then
    printf "${BOLD}Enter search term:${NC} "
    read -r search_term
else
    search_term="$*"
fi

if [ -z "$search_term" ]; then
    die "Search term cannot be empty."
fi

query=$(urlencode "$search_term")
results_file="$TEMP_DIR/final_results.tsv"
> "$results_file"

if ! search_torrents "$query" "$results_file"; then
    die "Search failed or no results found for '$search_term'."
fi

if [ ! -s "$results_file" ]; then
    die "No results with seeders found for '$search_term'."
fi

sort -t$'\t' -k3,3nr -o "$results_file" "$results_file"

log_info "Found $(wc -l < "$results_file") results. Opening selection interface..."

selected=$(fzf < "$results_file" \
    --reverse --cycle \
    --prompt="Select a torrent to stream: " \
    --delimiter='\t' --with-nth=2 \
    --preview='echo -e "Title: {2}\n\nSeeders: {3}\nLeechers: {4}\nSize: {5}"' \
    --preview-window='right:50%:wrap')

if [ -n "$selected" ]; then
    IFS=$'\t' read -r hash title seeders leechers size <<< "$selected"

    clear

    if [[ ! "$hash" =~ ^[a-f0-9]{40}$ ]]; then
        die "Invalid torrent hash format: $hash"
    fi

    trackers=$(fetch_trackers)
    magnet="magnet:?xt=urn:btih:$hash&dn=$(urlencode "$title")${trackers}"

    if $DOWNLOAD_MODE; then
        log_info "Adding torrent to Transmission: $title"
        transmission-qt --add "$magnet" && log_info "Successfully added to Transmission!" || die "Failed to add torrent. Is Transmission running?"
    else
        log_info "Starting stream: $title"
        log_warn "Do not close this terminal until you are finished watching."

        peerflix "$magnet" --mpv --not-on-top --path "$TEMP_DIR" &
        peerflix_pid=$!

        if ! wait "$peerflix_pid"; then
            log_warn "Stream ended or was interrupted."
        fi
    fi
else
    log_info "No torrent selected. Exiting."
fi
