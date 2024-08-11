#!/bin/sh

echo "Enter the name of the movie or show:"
read query
query=$(printf '%s' "$query" | tr ' ' '+')
echo "Searching for: $query"

search_results=$(curl -s "https://tprbay.xyz/search/$query/1/")
torrents=$(echo "$search_results" | grep -Po 'torrent/[0-9]+/[^"]+' | sort -u)

if [ -z "$torrents" ]; then
    echo "No results found for query: $query"
    exit 1
fi

echo "Found torrents:"
count=1
for torrent in $torrents; do
    # Extract torrent name from the URL
    title=$(echo "$torrent" | sed -e 's|torrent/[0-9]+/||' -e 's|%20| |g' -e 's|_| |g')
    echo "$count) $title"
    count=$((count + 1))
done

echo "Enter the number of the torrent you want to select:"
read selection

# Validate the user's selection
if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -le 0 ] || [ "$selection" -gt $((count - 1)) ]; then
    echo "Invalid selection."
    exit 1
fi