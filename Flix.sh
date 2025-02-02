#!/bin/sh 

if [ $# -eq 0 ]; then
    echo "Error: Please provide a search term"
    exit 1
fi

query=$(printf '%s' "$*" | tr ' ' '+')
echo "Searching for $query"

# Function to fetch results with retries
fetch_results() {
    local max_retries=5
    local retry_count=0
    local success=false

    while [ $retry_count -lt $max_retries ] && [ "$success" = false ]; do
        if readarray -t movies < <(curl -s --retry 3 --retry-delay 2 "https://1337x.pics/xsearch?q=$query&sort=seeders" | grep -Eo 'torrent/[0-9]{7}/[a-zA-Z0-9?-]*' | head -n 5); then
            if [ ${#movies[@]} -gt 0 ]; then
                success=true
                break
            fi
        fi
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
            echo "No results found, retrying ($retry_count/$max_retries)..."
            sleep 10
        fi
    done

    if [ "$success" = false ]; then
        echo "Error: Failed to fetch results after $max_retries attempts"
        exit 1
    fi
}

# Call the fetch function
fetch_results

# Display results
echo "Movies found:"
for i in "${!movies[@]}"; do
    echo "$((i+1)). ${movies[$i]##*/}"
done

# Get user selection with validation
while true; do
    read -p "Select a movie (1-${#movies[@]}): " selection
    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le ${#movies[@]} ]; then
        break
    fi
    echo "Invalid selection. Please enter a number between 1 and ${#movies[@]}"
done

selection=$((selection-1))
movie=${movies[$selection]}

# Fetch magnet link
magnet=$(curl -s "https://1337x.pics/$movie/" | grep -Po "magnet:\?xt=urn:btih:[a-zA-Z0-9]*")

# Check if magnet link was found
if [ -z "$magnet" ]; then
    echo "Error: Could not fetch magnet link"
    exit 1
fi

echo "Links Fetched: $magnet"

# Check if peerflix is installed
if ! command -v peerflix &> /dev/null; then
    echo "Error: peerflix is not installed"
    echo "Install it using: npm install -g peerflix"
    exit 1
fi

# Run peerflix with error handling
if ! peerflix -k "$magnet" --not-on-top --remove; then
    echo "Error: Failed to start streaming"
    exit 1
fi
