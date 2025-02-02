#!/bin/sh

query=$(echo "$1" | sed 's/ /+/g')
query=$(printf '%s' "$*" | tr ' ' '+' )
echo "Searching for $query"

movies=($(curl -s "https://1337x.pics/xsearch?q=$query&sort=seeders" | grep -Eo "torrent\/[0-9]{7}\/[a-zA-Z0-9?-]*" | head -n 5))

echo "Movies found:"
for i in "${!movies[@]}"; do
    echo "$((i+1)). ${movies[$i]##*/}"
done

read -p "Select a movie (1-${#movies[@]}): " selection
selection=$((selection-1))
movie=${movies[$selection]}

magnet=$(curl -s https://1337x.pics/$movie/ | grep -Po "magnet:\?xt=urn:btih:[a-zA-Z0-9]*")
echo "Links Fetched: $magnet"

peerflix -k $magnet --no-peer
